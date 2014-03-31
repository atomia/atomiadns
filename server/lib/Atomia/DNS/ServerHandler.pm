#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::ServerHandler;

use Moose;
use Config::General;
use DBI;
use DBD::Pg qw(:pg_types);
use Data::Dumper;
use Authen::Passphrase::BlowfishCrypt;
use Digest::SHA qw(sha1_hex);
use Atomia::DNS::Signatures;
use MIME::Base64;
use Net::DNS::RR;

has 'conn' => (is => 'rw', isa => 'Any', default => undef);
has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");

sub BUILD {
	my $self = shift;

	die("$self is not blessed") unless blessed($self);
        my $conf = new Config::General($self->configfile);
        die("config not found at $self->configfile") unless defined($conf);
        my %config = $conf->getall;
        $self->config(\%config);
	$self->validate_db_config();
};

sub matchSignature {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	die("number of parameters doesn't match the signature for $method (" . join(",", @$signature) . ")") unless scalar(@$signature) == scalar(@_);
	for (my $idx = 0; $idx < scalar(@_); $idx++) {
		my $param = $_[$idx];
		my $sig = $signature->[$idx];
		my $message = "parameter " . ($idx + 1) . " doesn't match signature $sig";

		die($message) unless defined($param);
		die($message) if ($sig eq "int" || $sig eq "bigint") && !($param =~ /^\d+$/);

		if ($sig eq "array" || $sig eq "array[resourcerecord]" || $sig eq "zone" || $sig eq "array[hostname]" || $sig eq "array[int]") {
			my $itemname = ($sig eq "array" || $sig eq "array[int]") ? "item" : ($sig eq "zone" ? "label" : ($sig eq "array[hostname]" ? "hostname" : "resourcerecord"));
			# Convert <someseq><$itemname>foo</$itemname><$itemname>bar</$itemname></someseq> to array from hash
			if (ref($param) eq "HASH" && scalar(keys(%$param)) == 1 && defined($param->{$itemname})) {
				if (ref($param->{$itemname}) eq "ARRAY") {
					$_[$idx] = $param->{$itemname};
				} else {
					$_[$idx] = [ $param->{$itemname} ];
				}
			} else {
				die($message) if ref($param) ne "ARRAY";
			}
		}
	}
}

sub handleVoid {
	my $self = shift;
	my $account_id = shift;
	my $method = shift;
	my $signature = shift;

	$self->handleAll($method, $signature, 1, $account_id, @_);
	return SOAP::Data->new(name => "status", value => "ok")->type("string");
}

sub handleRecordArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $records = $sth->fetchall_arrayref({});
	die("no resourcerecord returned from database") unless defined($records) && !$DBI::err;

	my @soaprecords = map {
		foreach my $key (keys %$_) {
			if ($key =~ /^record_/) {
				my $value = $_->{$key};
				delete($_->{$key});
				$key =~ s/^record_//;
				$_->{$key} = $value;
			}
		}
	
		SOAP::Data->new(name => "resourcerecord", value => $_);	
	} @$records;

	return SOAP::Data->new(name => "resourcerecords", value => \@soaprecords);
}

sub handleKeySet {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $records = $sth->fetchall_arrayref({});
	die("no keyset returned from database") unless defined($records) && !$DBI::err;

	my @soapkeyset = map {
		foreach my $entry_key (keys %$_) {
			if ($entry_key =~ /^key_/) {
				my $value = $_->{$entry_key};
				delete($_->{$entry_key});
				$entry_key =~ s/^key_//;
				$_->{$entry_key} = $value;
			}
		}
	
		SOAP::Data->new(name => "key", value => $_);
	} @$records;

	return SOAP::Data->new(name => "keyset", value => \@soapkeyset);
}

sub handleDSSet {
	my $self = shift;
	my $method = shift;
	my $signature = shift;
	my $zone = shift;

	shift(@$signature);

	my $sth = $self->handleAll($method, $signature, 0, undef);

	my $records = $sth->fetchall_arrayref({});
	die("no keyset returned from database") unless defined($records) && !$DBI::err;

	my $soap_dsset = [];
	KEY: foreach my $key (@$records) {
		next KEY unless defined($key) && ref($key) eq 'HASH'
			&& $key->{"key_keytype"} eq "KSK"
			&& $key->{"key_algorithm"} =~ /^RSA/
			&& $key->{"key_activated"} == 1;

		my $dsset = $self->generateDSFromPrivateKey($zone, $key->{"key_keydata"});
		die("no DS records generated despite finding active KSK") unless defined($dsset) && ref($dsset) eq "ARRAY" && scalar(@$dsset) > 0;

		foreach my $ds (@$dsset) {
			push @$soap_dsset, SOAP::Data->new(name => "ds", value => { digest => $ds->digest(), digestType => $ds->digtype(), alg => $ds->algorithm(), keyTag => $ds->keytag() });
		}
	}

	return SOAP::Data->new(name => "dsset", value => $soap_dsset);
}

sub generateDSFromPrivateKey {
	my $self = shift;
	my $zone = shift;
	my $keydata = shift;

	die "invalid zone" unless defined($zone) && length($zone) > 0;
	$zone = $zone . "." unless $zone =~ /\.$/;

	if (defined($keydata) && $keydata =~ m'^Algorithm:\s+(\d+).*^Modulus:\s+(.*?)$.*^PublicExponent:\s+(.*?)$'ms) {
		my $algorithm = $1;
		my $modulus = decode_base64($2);
		my $exponent = decode_base64($3);
		my $exponent_length;
		if (length($exponent) > 255) {
			$exponent_length = pack("Cn", chr(0), length($exponent));
		} else {
			$exponent_length = pack("C", length($exponent));
		}

		my $rrtext = sprintf("$zone IN DNSKEY 257 3 %d %s", $algorithm, encode_base64($exponent_length . $exponent . $modulus, ''));
		my $dnskey = Net::DNS::RR->new($rrtext);
		if (defined($dnskey) && $dnskey->is_sep()) {
			my $ds_set = [];
			foreach my $digtype ("SHA1", "SHA256") {
				push @$ds_set, Net::DNS::RR::DS->create($dnskey, digtype => $digtype);
			}

			return $ds_set;
		} else {
			die("constructed key was not KSK, this is a bug");
		}
	} else {
		die "invalid private key format";
	}
}

sub handleZSKInfo {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $records = $sth->fetchall_arrayref({});
	die("no keyset returned from database") unless defined($records) && !$DBI::err;

	my @soapkeyset = map {
		foreach my $entry_key (keys %$_) {
			if ($entry_key =~ /^zskinfo_/) {
				my $value = $_->{$entry_key};
				delete($_->{$entry_key});
				$entry_key =~ s/^zskinfo_//;
				$_->{$entry_key} = $value;
			}
		}
	
		SOAP::Data->new(name => "key", value => $_);
	} @$records;

	return SOAP::Data->new(name => "zskinfo", value => \@soapkeyset);
}

sub handleZoneMetadata {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $records = $sth->fetchall_arrayref({});
	die("no metadata returned from database") unless defined($records) && !$DBI::err;

	my @soapmetadata = map {
		SOAP::Data->new(name => "metadataEntry", value => { key => $_->{"metadata_key"}, value => $_->{"metadata_value"} });
	} @$records;

	return SOAP::Data->new(name => "metadata", value => \@soapmetadata);
}

sub handleInt {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no resourcerecord returned from database") unless defined($rows) && !$DBI::err;

	die("more than one row returned for scalar type") unless scalar(@$rows) == 1; 
	die("more than one column returned for scalar type") unless scalar(@{$rows->[0]}) == 1; 

	my $intval = $rows->[0]->[0];
	die("bad data returned from database, expected integer") unless defined($intval) && $intval =~ /^\d+$/;

	return SOAP::Data->new(type => "integer", value => $intval);
}

sub handleAddKey {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	die "invalid algoritm or keysize" unless defined($_[0]) && $_[0] =~ /^[A-Z0-9]+$/ && defined($_[1]) && $_[1] =~ /^\d+$/;

	my $generation_command = sprintf "%s %s %d", "generate_private_key", $_[0], $_[1];
	eval {
		my $key = `$generation_command 2> /dev/null`;
		my $retval = $? >> 8;
		if ($retval) {
			die "error generating key, generate_private_key exit value was $retval";
		}

		die "couldn't generate key" unless defined($key) && length($key) > 0;

		push @_, $key;
	};

	if ($@) {
		my $exception = $@;
		die "error generating key: $exception";
	}

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no resourcerecord returned from database") unless defined($rows) && !$DBI::err;

	die("more than one row returned for scalar type") unless scalar(@$rows) == 1; 
	die("more than one column returned for scalar type") unless scalar(@{$rows->[0]}) == 1; 

	my $intval = $rows->[0]->[0];
	die("bad data returned from database, expected integer") unless defined($intval) && $intval =~ /^\d+$/;

	return SOAP::Data->new(name => "keyid", type => "integer", value => $intval);
}

sub handleStringArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		SOAP::Data->new(name => "item", value => $_->[0])
	} @$rows;

	return SOAP::Data->new(name => "stringarray", value => \@rowarray);
}

sub handleZones {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		SOAP::Data->new(name => "item", value => $_->[0])
	} @$rows;

	my $total = scalar(@$rows) == 0 ? 0 : $rows->[0]->[1];

	return SOAP::Data->new(name => "zones", value => { total => $total, zones => SOAP::Data->new(name => "zones", value => \@rowarray) });
}

sub handleString {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();

	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;
	die("more than one row returned for scalar type") unless scalar(@$rows) == 1; 
	die("more than one column returned for scalar type") unless scalar(@{$rows->[0]}) == 1; 

	my $stringval = $rows->[0]->[0];
	die("bad data returned from database, expected string") unless defined($stringval) && length($stringval) > 0;

	return SOAP::Data->new(type => "string", value => $stringval);
}

sub handleBinaryZone {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref({});
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	map {
		foreach my $key (keys %$_) {
			if ($key =~ /^record_/) {
				my $value = $_->{$key};
				delete($_->{$key});
				$key =~ s/^record_//;
				$_->{$key} = $value;
			}
		}
	} @$rows;

	my $zone;
	foreach my $row (@$rows) {
		$zone .= sprintf "%s %s %d %s %s\n", $row->{"label"}, $row->{"class"}, $row->{"ttl"}, $row->{"type"}, $row->{"rdata"};
	}

	chomp($zone);

	return SOAP::Data->new(name => "binaryzone", type => "base64", value => $zone);
}

sub handleBinaryZoneArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);
	die "error creating statement for fetching zones from database" unless defined($sth);

	my $binaryzones = [];
	my $current_zone = undef;
	my $current_binaryzone = undef;

	ROW: while (my $row = $sth->fetchrow_hashref) {
		die "error fetching zone rows from database" unless defined($row) && ref($row) eq "HASH" && !$DBI::err;

		my $zonename = $row->{"record_zone"};
		die "error fetching zone rows from database, invalid name" unless defined($zonename) && length($zonename) > 0;

		if (!defined($current_zone) || $current_zone ne $zonename) {
			if (defined($current_binaryzone) && $current_binaryzone ne "") {
				chomp($current_binaryzone);
				push @$binaryzones, { name => $current_zone, zone => SOAP::Data->new(name => "binaryzone", type => "base64", value => $current_binaryzone) };
			} elsif (defined($current_binaryzone) && $current_binaryzone eq "") {
				push @$binaryzones, { name => $current_zone };
			}

			$current_binaryzone = "";
			$current_zone = $zonename;
		}

		next ROW unless defined($row->{"record_id"});

		$current_binaryzone .= sprintf "%d %s %s %d %s %s\n", $row->{"record_id"}, $row->{"record_label"}, $row->{"record_class"}, $row->{"record_ttl"}, $row->{"record_type"}, $row->{"record_rdata"};
	}

	if (defined($current_binaryzone) && $current_binaryzone ne "") {
		chomp($current_binaryzone);
		push @$binaryzones, { name => $current_zone, zone => SOAP::Data->new(name => "binaryzone", type => "base64", value => $current_binaryzone) };
	} elsif (defined($current_binaryzone) && $current_binaryzone eq "") {
		push @$binaryzones, { name => $current_zone};
	}

	return SOAP::Data->new(name => "binaryzones", value => $binaryzones);
}

sub handleIntArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		SOAP::Data->new(name => "item", value => $_->[0])
	} @$rows;

	return SOAP::Data->new(name => "intarray", value => \@rowarray);
}

sub handleChanges {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $rows;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);
	$rows = $sth->fetchall_arrayref({});
	die("error polling database for changes: $DBI::errstr") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		foreach my $key (keys %$_) {
			if ($key =~ /^change_/) {
				my $value = $_->{$key};
				delete($_->{$key});
				$key =~ s/^change_//;
				$_->{$key} = $value;
			}
		}
	
		SOAP::Data->new(name => "changedzone", value => $_)
	} @$rows;

	return SOAP::Data->new(name => "changes", value => \@rowarray);
}

sub handleAllowedTransfer {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $rows;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);
	$rows = $sth->fetchall_arrayref({});
	die("error polling database for allowed zone transfers: $DBI::errstr") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		SOAP::Data->new(name => "allowedtransfer", value => $_)
	} @$rows;

	return SOAP::Data->new(name => "allowedtransfers", value => \@rowarray);
}

sub handleZone {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref({});
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	map {
		foreach my $key (keys %$_) {
			if ($key =~ /^record_/) {
				my $value = $_->{$key};
				delete($_->{$key});
				$key =~ s/^record_//;
				$_->{$key} = $value;
			}
		}
	} @$rows;

	my %labels;
	my $zone = [];
	foreach my $row (@$rows) {
		die("row without label returned") unless defined($row) && defined($row->{"label"});
		my $label = $row->{"label"};

		my $label_records = $labels{$label};
		unless (defined($label_records)) {
			$label_records = [];
			$labels{$label} = $label_records;
			push(@$zone, SOAP::Data->new(name => "label", value => { name => $label, records => $label_records }));
		}
	
		push (@$label_records, SOAP::Data->new(name => "resourcerecord", value => $row));	
	}

	return SOAP::Data->new(name => "zone", value => $zone);
}

sub handleSlaveZone {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref({});
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	map {
		foreach my $key (keys %$_) {
			if ($key =~ /^record_/) {
				my $value = $_->{$key};
				delete($_->{$key});
				$key =~ s/^record_//;
				$_->{$key} = $value;
			}
		}
	} @$rows;

	my $zones = [];
	foreach my $row (@$rows) {
		push (@$zones, SOAP::Data->new(name => "zone", value => $row));	
	}

	return SOAP::Data->new(name => "slavezones", value => $zones);
}

sub handleZoneStruct {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, undef, @_);

	my $rows = $sth->fetchall_arrayref({});
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @zones = map {
		SOAP::Data->new(name => "zone", value => $_);
	} @$rows;

	return SOAP::Data->new(name => "zones", value => \@zones);
}

sub handleAll {
	my $self = shift;
	my $method = shift;
	my $signature = shift;
	my $void = shift;
	my $account_id = shift;

	if (defined($account_id) && $account_id =~ /^\d+$/ && $method =~ /^(Add(Slave)?Zone)|(RestoreZone(Binary)?)$/) {
		unshift @_, $account_id;
		unshift @$signature, "int";
		$method .= "Auth";
	}

	my $placeholders = "";
	for (my $idx = 0; $idx < scalar(@_); $idx++) {
		$placeholders .= ", " if $idx > 0;
		$placeholders .= "?";
	}

	my $statement_evaluated = 0;
	my $zones_for_bulk_operation = undef;
	my $sth = undef;
	eval {
		$method =~ s/Binary//;
		$method =~ s/RestoreZoneBulk$/RestoreZone/;
		$method =~ s/GetDNSSECKeysDS/GetDNSSECKeys/;

		$sth = $self->dbi->prepare($void ? "SELECT $method($placeholders)" : "SELECT * FROM $method($placeholders)");
		die("error in dbi->prepare") unless defined($sth);

		PARAM: for (my $idx = 0; $idx < scalar(@_); $idx++) {
			if ($signature->[$idx] eq "int") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_INT4 });
			} elsif ($signature->[$idx] eq "bigint") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_INT8 });
			} elsif ($signature->[$idx] eq "array") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_VARCHARARRAY });
			} elsif ($signature->[$idx] eq "array[int]") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_INT4ARRAY });
			} elsif ($signature->[$idx] eq "array[resourcerecord]") {
				my $record = $_[$idx];
				die("bad resourcerecord-array passed") unless defined($record) && ref($record) eq "ARRAY";
				die("resourcerecord[] can't be empty") unless scalar(@$record) > 0;

				my @arrayrecord = map {
					$_->{"id"} = -1 unless defined($_->{"id"});
					die("bad format of resourcerecord.id") unless $_->{"id"} =~ /^-?\d+$/;
					die("bad format of resourcerecord.label: " . Dumper($_)) unless defined($_->{"label"}) && length($_->{"label"}) > 0;
					die("bad format of resourcerecord.class") unless defined($_->{"class"}) && length($_->{"class"}) > 0;
					die("bad format of resourcerecord.ttl") unless defined($_->{"ttl"}) && $_->{"ttl"} =~ /^\d+$/;
					die("bad format of resourcerecord.class") unless defined($_->{"type"}) && length($_->{"type"}) > 0;
					die("bad format of resourcerecord.rdata") unless defined($_->{"rdata"}) && length($_->{"rdata"}) > 0;

					[ $_->{"id"}, $_->{"label"}, $_->{"class"}, $_->{"ttl"}, $_->{"type"}, $_->{"rdata"} ]
				} @$record;

				$sth->bind_param($idx + 1, \@arrayrecord, { pg_type => PG_VARCHAR});

			} elsif ($signature->[$idx] eq "array[hostname]") {
				my $hostnames = $_[$idx];
				die("bad hostname-array passed") unless defined($hostnames) && ref($hostnames) eq "ARRAY";
				die("hostname[] can't be empty") unless scalar(@$hostnames) > 0;

				my @hostnamearray = map {
					die("bad format of hostname.zone") unless defined($_->{"zone"}) && length($_->{"zone"}) > 0;
					die("bad format of hostname.label") unless defined($_->{"label"}) && length($_->{"label"}) > 0;

					[ $_->{"zone"}, $_->{"label"} ]
				} @$hostnames;

				$sth->bind_param($idx + 1, \@hostnamearray, { pg_type => PG_VARCHAR});

			} elsif ($signature->[$idx] eq "zone" || $signature->[$idx] eq "binaryzone") {
				my $zone = $_[$idx];
				my $records = [];

				if ($signature->[$idx] eq "binaryzone") {
					die "bad format of binaryzone, should be a base64 encoded string" unless defined($zone) && ref($zone) eq '';
					chomp $zone;

					my @binaryarray = map {
						my @arr = split(/ /, $_, 5);
						die("bad format of binaryzone: row doesn't have 5 space separated fields") unless scalar(@arr) == 5;
						{ label => $arr[0], class => $arr[1], ttl => $arr[2], type => $arr[3], rdata => $arr[4] }
					} split(/\n/, $zone);

					$records = \@binaryarray;
				} else {
					die("bad format of zone, should an array of structs, containing name and records") unless defined($zone) && ref($zone) eq "ARRAY";

					foreach my $labelrecords (map { $_->{"records"} } @$zone) {

						# Convert <someseq><resourcerecord>foo</resourcerecord><resourcerecord>bar</$itemname></someseq> to array from hash
						if (defined($labelrecords) && ref($labelrecords) eq "HASH" && scalar(keys(%$labelrecords)) == 1 && defined($labelrecords->{"resourcerecord"})) {
							if (ref($labelrecords->{"resourcerecord"}) eq "ARRAY") {
								$labelrecords = $labelrecords->{"resourcerecord"};
							} else {
								$labelrecords = [ $labelrecords->{"resourcerecord"} ];
							}
						}

						die("bad format of zone, records should be an array of resourcerecords not " . Dumper($labelrecords)) unless defined($labelrecords) && ref($labelrecords) eq "ARRAY";
						push (@$records, @$labelrecords);
					}
				}

				my @arrayrecord = map {
					$_->{"id"} = -1 unless defined($_->{"id"});
					die("bad format of resourcerecord.id") unless $_->{"id"} =~ /^-?\d+$/;
					die("bad format of resourcerecord.label: " . Dumper($_)) unless defined($_->{"label"}) && length($_->{"label"}) > 0;
					die("bad format of resourcerecord.class") unless defined($_->{"class"}) && length($_->{"class"}) > 0;
					die("bad format of resourcerecord.ttl") unless defined($_->{"ttl"}) && $_->{"ttl"} =~ /^\d+$/;
					die("bad format of resourcerecord.class") unless defined($_->{"type"}) && length($_->{"type"}) > 0;
					die("bad format of resourcerecord.rdata") unless defined($_->{"rdata"}) && length($_->{"rdata"}) > 0;

					[ $_->{"id"}, $_->{"label"}, $_->{"class"}, $_->{"ttl"}, $_->{"type"}, $_->{"rdata"} ]
				} @$records;

				$sth->bind_param($idx + 1, \@arrayrecord, { pg_type => PG_VARCHAR});

			} elsif ($signature->[$idx] eq "array[bulkzones]") {
				die "array[bulkzones] can't be used anywhere except in the first parameter" unless $idx == 0;

				my $zones = $_[$idx];
				die "bad format of array[bulkzones]" unless defined($zones) && ref($zones) eq "ARRAY";
				$zones_for_bulk_operation = $zones;

			} elsif ($signature->[$idx] eq "array[binaryzone]") {
				die "array[binaryzone] can't be used anywhere except in the last parameter" unless $idx == scalar(@_) - 1;

				my $zones = $_[$idx];

				die "bad format of array[binaryzone]" unless defined($zones) && ref($zones) eq 'ARRAY';
				die "zone-array passed in first parameter was not the same length as the binaryzone-array" unless defined($zones_for_bulk_operation) &&
					ref($zones_for_bulk_operation) eq "ARRAY" && scalar(@$zones_for_bulk_operation) == scalar(@$zones);

				my $zone_idx = 0;
				foreach my $zone (@$zones) {
					die "bad format of binaryzone, should be a base64 encoded string" unless defined($zone) && ref($zone) eq '';
					chomp $zone;

					my @binaryarray = map {
						my @arr = split(/ /, $_, 5);
						die("bad format of binaryzone: row doesn't have 5 space separated fields") unless scalar(@arr) == 5;
						{ label => $arr[0], class => $arr[1], ttl => $arr[2], type => $arr[3], rdata => $arr[4] }
					} split(/\n/, $zone);

					my $records = \@binaryarray;

					my @arrayrecord = map {
						$_->{"id"} = -1 unless defined($_->{"id"});
						die("bad format of resourcerecord.id") unless $_->{"id"} =~ /^-?\d+$/;
						die("bad format of resourcerecord.label: " . Dumper($_)) unless defined($_->{"label"}) && length($_->{"label"}) > 0;
						die("bad format of resourcerecord.class") unless defined($_->{"class"}) && length($_->{"class"}) > 0;
						die("bad format of resourcerecord.ttl") unless defined($_->{"ttl"}) && $_->{"ttl"} =~ /^\d+$/;
						die("bad format of resourcerecord.class") unless defined($_->{"type"}) && length($_->{"type"}) > 0;
						die("bad format of resourcerecord.rdata") unless defined($_->{"rdata"}) && length($_->{"rdata"}) > 0;
	
						[ $_->{"id"}, $_->{"label"}, $_->{"class"}, $_->{"ttl"}, $_->{"type"}, $_->{"rdata"} ]
					} @$records;

					$sth->bind_param(1, $zones_for_bulk_operation->[$zone_idx], { pg_type => PG_VARCHAR});
					$sth->bind_param($idx + 1, \@arrayrecord, { pg_type => PG_VARCHAR});

					eval {
						my $ret = $sth->execute();
						die("bad response for $method: $DBI::errstr") unless defined($ret);
					};

					if ($@) {
						die($@);
					}

					$zone_idx++;
				}

				$statement_evaluated = 1;
			} elsif ($signature->[$idx] eq "password") {
				my $password = $_[$idx];
				die "password can't be empty" unless defined($password) && length($password) > 0;

				my $ppr = Authen::Passphrase::BlowfishCrypt->new(cost => 10, salt_random => 1, passphrase => $password);
				die "error creating bcrypt hash from password" unless defined($ppr);

				$sth->bind_param($idx + 1, $ppr->as_crypt(), { pg_type => PG_VARCHAR });
			} else {
				# Default is varchar
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_VARCHAR });
			}
		}
	};

	if ($@) {
		die("error preparing statement for $method invocation: $@");
	}

	return undef if $statement_evaluated;

	eval {
		my $ret = $sth->execute();
		die("bad response for $method: $DBI::errstr") unless defined($ret);
	};

	if ($@) {
		die($@);
	}

	return $sth;
}

sub validate_db_config {
	my $self = shift;

	die("you have to specify db_name, db_hostname, db_username and db_password") unless defined($self->config->{"db_name"}) &&
		defined($self->config->{"db_hostname"}) && defined($self->config->{"db_username"}) && defined($self->config->{"db_password"});
}

sub dbi {
	my $self = shift;

        $self->validate_db_config();

        my $dbh = $self->conn;

        if (defined($dbh) && $dbh->ping) {
                return $dbh;
        } else {
		my $dbname = $self->config->{"db_name"};
                my $dbhost = $self->config->{"db_hostname"};
                my $dbuser = $self->config->{"db_username"};
                my $dbpass = $self->config->{"db_password"};

                my $dsn = "DBI:Pg:dbname=$dbname;host=$dbhost";
                my @conn_args = ($dsn, $dbuser, $dbpass, { PrintError => 0, PrintWarn => 0 });

                $dbh = DBI->connect(@conn_args);
                die("error connecting to $dbname") unless defined($dbh) && $dbh;

                $self->conn($dbh);
                return $dbh;
        }
}

sub generateException {
	my $self = shift;
	my ($class, $subclass, $message) = @_;

	my $detail = SOAP::Data->new(name => $class, value => {
		subtype => $subclass,
		description => $message
	});

	die SOAP::Fault -> faultcode($class . "." . $subclass)
			-> faultstring($message)
			-> faultdetail($detail);
}

sub mapExceptionToFault {
	my $self = shift;
	my $exception = shift;

# LogicalError.*
	if ($exception =~ /duplicate key value violates unique constraint/) {
		$self->generateException('LogicalError', 'Uniqueness', $exception);
	} elsif ($exception =~ /zone .* not found/) {
		$self->generateException('LogicalError', 'ZoneNotFound', $exception);
	} elsif ($exception =~ /nameserver .* not found/) {
		$self->generateException('LogicalError', 'NameserverNotFound', $exception);
	} elsif ($exception =~ /record .* doesn.t exist in zone/) {
		$self->generateException('LogicalError', 'RecordNotFound', $exception);
	} elsif ($exception =~ /account .* not found/) {
		$self->generateException('LogicalError', 'AccountNotFound', $exception);
	} elsif ($exception =~ /both as source and destination/) {
		$self->generateException('LogicalError', 'SameSourceAndDestination', $exception);
	} elsif ($exception =~ /moving .* cross.* are not supported/) {
		$self->generateException('LogicalError', 'CrossObjectMove', $exception);
	} elsif ($exception =~ /and CNAME is not allowed with other data/) {
		$self->generateException('LogicalError', 'CNAMEAndOtherData', $exception);
	} elsif ($exception =~ /is different from existing ttl for this label\/class\/type triplet/) {
		$self->generateException('LogicalError', 'DifferentTTLForSameLabelClassAndType', $exception);
	} elsif ($exception =~ /zone needs to have/) {
		$self->generateException('LogicalError', 'ZoneRequiredRecords', $exception);
	} elsif ($exception =~ /all labels have to have records/) {
		$self->generateException('LogicalError', 'EmptyLabel', $exception);
# InvalidParametersError.*
	} elsif ($exception =~ /(refresh|retry|expire|minimum) value of .* is out of range/) {
		$self->generateException('InvalidParametersError', 'Soa' . $1, $exception);
	} elsif ($exception =~ /is not an available type/) {
		$self->generateException('InvalidParametersError', 'BadType', $exception);
	} elsif ($exception =~ /isn.t allowed rdata for (.*), synopsis/) {
		$self->generateException('InvalidParametersError', 'BadRdataFor' . $1, $exception);
	} elsif ($exception =~ /bad changestatus .* when updating change with id/) {
		$self->generateException('InvalidParametersError', 'BadChangeStatus', $exception);
	} elsif ($exception =~ /violates check constraint/) {
		$self->generateException('InvalidParametersError', 'BadInput', $exception);
	} elsif ($exception =~ /number of parameters doesn.t match the signature for/) {
		$self->generateException('InvalidParametersError', 'BadNumberOfParameters', $exception);
	} elsif ($exception =~ /parameter \d+ doesn't match signature /) {
		$self->generateException('InvalidParametersError', 'BadParameterType', $exception);
	} elsif ($exception =~ /bad format of (\w+)\.(\w+)/) {
		$self->generateException('InvalidParametersError', 'Bad' . $1 . $2, $exception);
	} elsif ($exception =~ /bad .*-array passed |.*\[\] can.t be empty/) {
		$self->generateException('InvalidParametersError', 'BadArray', $exception);
# AuthError.*
	} elsif ($exception =~ /unauthorized access/) {
		$self->generateException('AuthError', 'NotAuthenticated', $exception);
	} elsif ($exception =~ /invalid username or password/) {
		$self->generateException('AuthError', 'NotAuthenticated', $exception);
	} elsif ($exception =~ /invalid token/) {
		$self->generateException('AuthError', 'NotAuthenticated', $exception);
	} elsif ($exception =~ /authorization failed/) {
		$self->generateException('AuthError', 'NotAuthorized', $exception);
# SystemError.*
	} elsif ($exception =~ /no .* returned from database|bad data returned from database|more than one .* returned for scalar|row without label returned|error polling database for changes/) {
		$self->generateException('SystemError', 'DatabaseBadResult', $exception);
	} elsif ($exception =~ /error connecting to /) {
		$self->generateException('SystemError', 'DatabaseConnection', $exception);
	} elsif ($exception =~ /error preparing statement for|error in dbi->prepare/) {
		$self->generateException('SystemError', 'PreparingStatement', $exception);
	} else {
		$self->generateException('InternalError', 'UnknownException', $exception);
	}
}

sub retrieveAccount {
	my $self = shift;
	my $email = shift;

	my $ret = undef;
	$ret = eval {
		my $sth = $self->dbi->prepare("SELECT id, hash FROM account WHERE email = ?");
		die("error in dbi->prepare") unless defined($sth);

		$sth->bind_param(1, $email, { pg_type => PG_VARCHAR });

		my $ret = $sth->execute();
		die("bad response for retrieveAccount: $DBI::errstr") unless defined($ret);

		my $rows = $sth->fetchall_arrayref();
		die("no or invalid rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err
			&& scalar(@$rows) == 1 && ref($rows->[0]) eq "ARRAY" && scalar(@{$rows->[0]}) == 2 && length($rows->[0]->[1]) > 0;

		my $hash = $rows->[0]->[1];
		my $ppr = Authen::Passphrase::BlowfishCrypt->from_crypt($hash);
		die "invalid bcrypt hash in database" unless defined($ppr);

		return { id => $rows->[0]->[0], hash => $ppr };
	};

	if ($@) {
		return undef;
	} else {
		return $ret;
	}
}
		
sub authorizeZones {
	my $self = shift;
	my $zones = shift;
	my $account_id = shift;
	my $slave = shift;

	die "invalid indata in authorizeZones" unless defined($zones) && ref($zones) eq "ARRAY" && scalar(@$zones) > 0 && defined($account_id) && $account_id =~ /^\d+$/;

	$slave = 0 unless defined($slave) && $slave == 1;
	my $proc = $slave ? "AuthorizeSlaveZones" : "AuthorizeZones";

	my $ret = undef;
	$ret = eval {
		my $sth = $self->dbi->prepare("SELECT * FROM $proc(?, ?)");
		die("error in dbi->prepare") unless defined($sth);

		$sth->bind_param(1, $zones, { pg_type => PG_VARCHARARRAY });
		$sth->bind_param(2, $account_id, { pg_type => PG_INT4 });

		my $ret = $sth->execute();
		die("bad response for $proc: $DBI::errstr") unless defined($ret);

		my $rows = $sth->fetchall_arrayref();
		die("no or invalid rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err
			&& scalar(@$rows) == 1 && ref($rows->[0]) eq "ARRAY" && scalar(@{$rows->[0]}) == 1 && $rows->[0]->[0] =~ /^[01]$/;

		return $rows->[0]->[0];
	};

	if ($@) {
		return 0;
	} else {
		return $ret;
	}
}

sub authenticateRequest {
	my $self = shift;
	my $request = shift;


	my $authenticated_account = undef;

	eval {
		if (defined($request->headers_in->{'X-Auth-Username'}) && defined($request->headers_in->{'X-Auth-Password'})) {
			$authenticated_account = $self->authenticateAccount($request->headers_in->{'X-Auth-Username'}, $request->headers_in->{'X-Auth-Password'});
			die "invalid username or password" unless defined($authenticated_account) && (defined($authenticated_account->{"token"}) || defined($authenticated_account->{"admin"}));
			$request->headers_out->{'X-Auth-Token'} = $authenticated_account->{"token"} if defined($authenticated_account->{"token"});
		} elsif (defined($request->headers_in->{'X-Auth-Username'}) && defined($request->headers_in->{'X-Auth-Token'})) {
			$authenticated_account = $self->authenticateAccountToken($request->headers_in->{'X-Auth-Username'}, $request->headers_in->{'X-Auth-Token'});
			die "invalid token" unless defined($authenticated_account);
		}
	};

	if ($@) {
		my $exception = $@;
		my $require_auth = (defined($self->config->{"require_auth"}) && $self->config->{"require_auth"} eq "1") ? 1 : 0;
		die $exception if $require_auth;
	}

	return $authenticated_account;
}

sub authenticateAccount {
	my $self = shift;
	my $username = shift;
	my $password = shift;

	if (defined($username) && defined($self->config->{"auth_admin_user"}) && length($username) > 0 && $username eq $self->config->{"auth_admin_user"}) {
		if (defined($password) && length($password) > 0 && defined($self->config->{"auth_admin_pass"}) && $password eq $self->config->{"auth_admin_pass"}) {
			return { admin => 1 };
		} else {
			return undef;
		}
	}

	my $auth = $self->retrieveAccount($username);
	if (defined($auth)) {
		if ($auth->{"hash"}->match($password)) {
			return { id => $auth->{"id"}, token => $self->generateAccountToken($auth) }; 
		} else {
			return undef;
		}
	} else {
		return undef;
	}
}

sub authenticateAccountToken {
	my $self = shift;
	my $username = shift;
	my $token = shift;

	my $unix_timestamp = undef; 
	if ($token =~ /^(\d+)\//) {
		$unix_timestamp = $1;
		my $now = time();
		my $token_lifetime = $self->config->{"api_token_lifetime"} || 600;
		return undef if $now > $unix_timestamp + $token_lifetime;
	} else {
		return undef;
	}

	my $auth = $self->retrieveAccount($username);
	if (defined($auth)) {
		my $real_token = $self->generateAccountToken($auth, $unix_timestamp);
		if (defined($token) && defined($real_token) && length($token) > 0 && length($real_token) > 0 && $token eq $real_token) {
			return { id => $auth->{"id"} };
		} else {
			return undef;
		}
	} else {
		return undef;
	}
}

sub generateAccountToken {
	my $self = shift;
	my $auth = shift;
	my $unix_timestamp = shift;

	return undef unless !(defined($unix_timestamp)) || $unix_timestamp =~ /^\d+$/;
	return undef unless defined($auth) && ref($auth) eq "HASH" && defined($auth->{"hash"}) && ref($auth->{"hash"});

	my $ppr = $auth->{"hash"};
	my $hash = $ppr->as_crypt();
	return undef unless defined($hash) && ref($hash) eq '' && length($hash) > 0;

	unless (defined($unix_timestamp)) {
		$unix_timestamp = time();
	}

	my $token_data = sprintf "%d%s%s", $unix_timestamp, $hash, $self->config->{"db_password"};
	my $token_sha1 = sha1_hex($token_data);
	return undef unless defined($token_sha1) && length($token_sha1) > 0;

	return "$unix_timestamp/$token_sha1";
}

sub authorizeMethod {
	my $self = shift;
	my $method = shift;
	my $authenticated_account = shift;
	my @args = @_;

	my $require_auth = (defined($self->config->{"require_auth"}) && $self->config->{"require_auth"} eq "1") ? 1 : 0;
	return undef unless $require_auth;

	die "unauthorized access" unless defined($authenticated_account) && ref($authenticated_account) eq "HASH";

	return undef if defined($authenticated_account->{"admin"}) && $authenticated_account->{"admin"} == 1;

	die "unauthorized access" unless defined($authenticated_account->{"id"}) && $authenticated_account->{"id"} =~ /^\d+$/;

	my $account_id = $authenticated_account->{"id"};

	die "authorization failed, operation is admin only" unless defined($Atomia::DNS::Signatures::authorization_rules) && defined($Atomia::DNS::Signatures::authorization_rules->{$method});

	my @method_rules = split(" ", $Atomia::DNS::Signatures::authorization_rules->{$method});
	for (my $idx = 0; $idx < scalar(@method_rules); $idx++) {
		die "authorization failed, too few arguments for rule" unless $idx < scalar(@args);

		my $arg_to_authorize = $args[$idx];
		my $arg_rule = $method_rules[$idx];

		if ($arg_rule eq "authaccount") {
			my $account = $self->retrieveAccount($arg_to_authorize);
			die "authorization failed, permission denied for the account" unless defined($account) && ref($account) eq "HASH"
				&& defined($account->{"id"}) && $account->{"id"} =~ /^\d+$/ && $account->{"id"} == $account_id;
		} elsif ($arg_rule eq "authzone") {
			my $authorized = $self->authorizeZones([ $arg_to_authorize ], $account_id);
			die "authorization failed, permission denied for the zone" unless defined($authorized) && ref($authorized) eq '' && $authorized == 1;
		} elsif ($arg_rule eq "authslavezone") {
			my $authorized = $self->authorizeZones([ $arg_to_authorize ], $account_id, 1);
			die "authorization failed, permission denied for the slave zone" unless defined($authorized) && ref($authorized) eq '' && $authorized == 1;
		} elsif ($arg_rule eq "authzonearray") {
			my $authorized = $self->authorizeZones($arg_to_authorize, $account_id);
			die "authorization failed, permission denied for one of the zones" unless defined($authorized) && ref($authorized) eq '' && $authorized == 1;
		} elsif ($arg_rule ne "allow") {
			die "authorization failed, invalid rule";
		}
	}

	return $account_id;
}

sub handleOperation {
	my $self = shift;
	my $authenticated_account = shift;
	my $method = shift;
	my $signature_orig = shift;

	my @signature_copy = @$signature_orig;
	my $signature = \@signature_copy;

	die "invalid use of handleOperation" unless defined($method) && length($method) > 0 && defined($signature) && ref($signature) eq "ARRAY" && scalar(@$signature) > 0;

	my $return_type = shift(@$signature);
	$self->matchSignature($method, $signature, @_);

	my $account_id = $self->authorizeMethod($method, $authenticated_account, @_);

	my $retval = undef;

	if ($return_type eq "void") {
		$retval = $self->handleVoid($account_id, $method, $signature, @_);
	} elsif ($return_type eq "array[resourcerecord]") {
		$retval = $self->handleRecordArray($method, $signature, @_);
	} elsif ($return_type eq "array[string]") {
		$retval = $self->handleStringArray($method, $signature, @_);
	} elsif ($return_type eq "string") {
		$retval = $self->handleString($method, $signature, @_);
	} elsif ($return_type eq "binaryzone") {
		$retval = $self->handleBinaryZone($method, $signature, @_);
	} elsif ($return_type eq "array[binaryzone]") {
		$retval = $self->handleBinaryZoneArray($method, $signature, @_);
	} elsif ($return_type eq "array[int]" || $return_type eq "array[bigint]") {
		$retval = $self->handleIntArray($method, $signature, @_);
	} elsif ($return_type eq "zone") {
		$retval = $self->handleZone($method, $signature, @_);
	} elsif ($return_type eq "zones") {
		$retval = $self->handleZones($method, $signature, @_);
	} elsif ($return_type eq "slavezone") {
		$retval = $self->handleSlaveZone($method, $signature, @_);
	} elsif ($return_type eq "changes") {
		$retval = $self->handleChanges($method, $signature, @_);
	} elsif ($return_type eq "zonestruct") {
		$retval = $self->handleZoneStruct($method, $signature, @_);
	} elsif ($return_type eq "int") {
		$retval = $self->handleInt($method, $signature, @_);
	} elsif ($return_type eq "allowedtransfer") {
		$retval = $self->handleAllowedTransfer($method, $signature, @_);
	} elsif ($return_type eq "keyset") {
		$retval = $self->handleKeySet($method, $signature, @_);
	} elsif ($return_type eq "dsset") {
		$retval = $self->handleDSSet($method, $signature, @_);
	} elsif ($return_type eq "zskinfo") {
		$retval = $self->handleZSKInfo($method, $signature, @_);
	} elsif ($return_type eq "keyid") {
		$retval = $self->handleAddKey($method, $signature, @_);
	} elsif ($return_type eq "array[zonemetadata]") {
		$retval = $self->handleZoneMetadata($method, $signature, @_);
	} else {
		die("unknown return-type in signature: $return_type");
	}

	return $retval;
}

1;

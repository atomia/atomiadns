#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::ServerHandler;

use Moose;
use Config::General;
use DBI;
use DBD::Pg qw(:pg_types);
use Data::Dumper;

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
};

sub matchSignature {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	die("number of parameters doesn't match the signature for $method") unless scalar(@$signature) == scalar(@_);
	for (my $idx = 0; $idx < scalar(@_); $idx++) {
		my $param = $_[$idx];
		my $sig = $signature->[$idx];
		my $message = "parameter " . ($idx + 1) . " doesn't match signature $sig";

		die($message) unless defined($param);
		die($message) if $sig eq "int" && !($param =~ /^\d+$/);

		if ($sig eq "array" || $sig eq "array[resourcerecord]" || $sig eq "zone" || $sig eq "array[hostname]") {
			my $itemname = $sig eq "array" ? "item" : ($sig eq "zone" ? "label" : ($sig eq "array[hostname]" ? "hostname" : "resourcerecord"));
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
	my $method = shift;
	my $signature = shift;

	$self->handleAll($method, $signature, 1, @_);
	return SOAP::Data->new(name => "status", value => "ok")->type("string");
}

sub handleRecordArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

sub handleInt {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no resourcerecord returned from database") unless defined($rows) && !$DBI::err;

	die("more than one row returned for scalar type") unless scalar(@$rows) == 1; 
	die("more than one column returned for scalar type") unless scalar(@{$rows->[0]}) == 1; 

	my $intval = $rows->[0]->[0];
	die("bad data returned from database, expected integer") unless defined($intval) && $intval =~ /^\d+$/;

	return SOAP::Data->new(type => "integer", value => $intval);
}

sub handleStringArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, @_);

	my $rows = $sth->fetchall_arrayref();
	die("no rows returned from database") unless defined($rows) && ref($rows) eq "ARRAY" && !$DBI::err;

	my @rowarray = map {
		SOAP::Data->new(name => "item", value => $_->[0])
	} @$rows;

	return SOAP::Data->new(name => "stringarray", value => \@rowarray);
}

sub handleString {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

sub handleIntArray {
	my $self = shift;
	my $method = shift;
	my $signature = shift;

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

	my $sth = $self->handleAll($method, $signature, 0, @_);
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

	my $sth = $self->handleAll($method, $signature, 0, @_);
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

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

	my $sth = $self->handleAll($method, $signature, 0, @_);

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

	my $placeholders = "";
	for (my $idx = 0; $idx < scalar(@_); $idx++) {
		$placeholders .= ", " if $idx > 0;
		$placeholders .= "?";
	}

	my $statement_evaluated = 0;
	my $zones_for_bulk_operation = undef;
	my $sth = undef;
	eval {
		$method =~ s/Binary$//;
		$method =~ s/RestoreZoneBulk$/RestoreZone/;

		$sth = $self->dbi->prepare($void ? "SELECT $method($placeholders)" : "SELECT * FROM $method($placeholders)");
		die("error in dbi->prepare") unless defined($sth);

		PARAM: for (my $idx = 0; $idx < scalar(@_); $idx++) {
			if ($signature->[$idx] eq "int") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_INT4 });
			} elsif ($signature->[$idx] eq "array") {
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_VARCHARARRAY });
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
	} elsif ($exception =~ /bad format of (\w+)\.(\w+)/) {
		$self->generateException('InvalidParametersError', 'Bad' . $1 . $2, $exception);
	} elsif ($exception =~ /bad .*-array passed |.*\[\] can.t be empty/) {
		$self->generateException('InvalidParametersError', 'BadArray', $exception);
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

1;

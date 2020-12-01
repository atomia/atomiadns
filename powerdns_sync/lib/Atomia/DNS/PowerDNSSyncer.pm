#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::PowerDNSSyncer;

use Moose;
use Config::General;
use SOAP::Lite;
use Data::Dumper;
use Atomia::DNS::PowerDNSDatabase;
use Net::DNS::ZoneFile;

has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");
has 'soap' => (is => 'rw', isa => 'Any', default => undef);
has 'database' => (is => 'rw', isa => 'Any', default => undef);

sub BUILD {
	my $self = shift;

	my $conf = new Config::General($self->configfile);
	die("config not found at $self->configfile") unless defined($conf);
	my %config = $conf->getall;
	$self->config(\%config);

	my $db = Atomia::DNS::PowerDNSDatabase->new(config => $self->config);
	$self->database($db);

	my $soap_uri = $self->config->{"soap_uri"} || die("soap_uri not specified in " . $self->configfile);
	my $soap_cacert = $self->config->{"soap_cacert"};
	if ($soap_uri =~ /^https/) {
		die "with https as the transport you need to include the location of the CA cert in the soap_cacert config-file option" unless defined($soap_cacert) && -f $soap_cacert;
		$ENV{HTTPS_CA_FILE} = $soap_cacert;
	}

	my $soap_username = $self->config->{"soap_username"};
	my $soap_password = $self->config->{"soap_password"};
	if (defined($soap_username)) {
		die "if you specify soap_username, you have to specify soap_password as well" unless defined($soap_password);
		unless (defined(&SOAP::Transport::HTTP::Client::get_basic_credentials)) { # perhaps we should inspect method body and die if different credentials, but we'll give rope instead
			eval "sub SOAP::Transport::HTTP::Client::get_basic_credentials { return '$soap_username' => '$soap_password' }";
		}
	}

	my $soap = SOAP::Lite
		->  uri('urn:Atomia::DNS::Server')
		->  proxy($soap_uri, timeout => $self->config->{"soap_timeout"} || 600)
		->  on_fault(sub {
				my ($soap, $res) = @_;
				die((ref($res) && UNIVERSAL::isa($res, 'SOAP::SOM')) ? $res : ("got fault of type transport error: " . $soap->transport->status));
			});

	die("error instantiating SOAP::Lite") unless defined($soap);

	if (defined($soap_username)) {
		$soap->transport->http_request->header('X-Auth-Username' => $soap_username);
		$soap->transport->http_request->header('X-Auth-Password' => $soap_password);
	}

	$self->soap($soap);
};

sub sync_zone_transfers {
	my $self = shift;


	my $allowed_transfers = $self->soap->GetAllowedZoneTransfer();
	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers);
	$allowed_transfers = $allowed_transfers->result;
	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers) &&
		ref($allowed_transfers) eq "ARRAY";

	# TODO: sync allowed zone transfers
}

sub sync_dnssec_keys {
	my $self = shift;

	if (!defined($self->config->{"powerdns_sync_keys"}) || $self->config->{"powerdns_sync_keys"} ne "0") {
		my $keyset = $self->soap->GetDNSSECKeys();
		die("error fetching DNSSEC keyset, got no or bad result from soap-server") unless defined($keyset) &&
			$keyset->result && ref($keyset->result) eq "ARRAY";
		$keyset = $keyset->result;

		$self->database->sync_keyset($keyset);
		$self->database->set_dnssec_metadata(0, undef, $self->config->{"powerdns_zone_nsec_format"});
	} elsif (defined($self->config->{"powerdns_presigned_dnssec"}) && $self->config->{"powerdns_presigned_dnssec"} eq "1") {
		$self->database->set_dnssec_metadata(1, $self->config->{"powerdns_master_also_notify"}, $self->config->{"powerdns_zone_nsec_format"});
	} elsif (defined($self->config->{"powerdns_master_also_notify"})) {
		$self->database->set_dnssec_metadata(undef, $self->config->{"powerdns_master_also_notify"}, $self->config->{"powerdns_zone_nsec_format"});
	}
}

sub reload_updated_zones {
	my $self = shift;

	my $zones = $self->soap->GetChangedZonesBatch($self->config->{"servername"} || die("you have to specify servername in config"), 10000);
	die("error fetching updated zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	my $changes_to_keep = [];
	my $changes_to_keep_name = [];
	foreach my $zone (@$zones) {
		my $keep_zonename = $zone->{"name"} || die("bad data from GetUpdatedZones, zone not specified");
		my $keep_change_id = $zone->{"id"} || die("bad data from GetUpdatedZones, id not specified");
		push @$changes_to_keep_name, $keep_zonename;
		push @$changes_to_keep, $keep_change_id;

		if (scalar(@$changes_to_keep) > 1000) {
			$self->soap->MarkAllUpdatedExceptBulk($changes_to_keep_name, $changes_to_keep);
			$changes_to_keep = [];
			$changes_to_keep_name = [];
		}
	}

	if (scalar(@$changes_to_keep) > 0) {
		$self->soap->MarkAllUpdatedExceptBulk($changes_to_keep_name, $changes_to_keep);
	}

	my $num_zones = scalar(@$zones);
	my $bulk_size = 500;

	for (my $offset = 0; $offset < $num_zones; $offset += $bulk_size) {
		my $num = $num_zones - $offset;
		$num = $bulk_size if $num > $bulk_size;

		my @batch = @{$zones}[$offset .. ($offset + $num - 1)];

		my @get_zone_bulk_arg = map { $_->{"name"} } @batch;
		my $fetched_records_for_zones = $self->fetch_records_for_zones(\@get_zone_bulk_arg);

		my $changes_successful = [];
		my $changes_status = [];
		my $changes_message = [];

		foreach my $zone (@batch) {
			my $transaction = undef;
			my $change_id = undef;

			eval {
				$change_id = $zone->{"id"} || die("bad data from GetUpdatedZones, id not specified");

				my $zone_name = $zone->{"name"};

				if (defined($self->config->{"powerdns_presigned_dnssec"}) && $self->config->{"powerdns_presigned_dnssec"} eq "1") {
					my $mod_handler = $self->config->{"powerdns_presigned_dnssec_mod_script"};
					my $del_handler = $self->config->{"powerdns_presigned_dnssec_del_script"};
	
					my $mod = (scalar(@{$fetched_records_for_zones->{$zone->{"name"}}}) > 0);
					if ($mod) {
						if (defined($mod_handler)) {
							die "defined script for powerdns_presigned_dnssec_mod_script does not exist or is not executable: $mod_handler" unless -e $mod_handler && -x $mod_handler;
							my $output = `$mod_handler "$zone_name" 2>&1`;

							my $status = $? >> 8;
							if ($status) {
								die "defined script for powerdns_presigned_dnssec_mod_script ($mod_handler) returned error status $status and the following output: $output";
							}
						}

						$self->database->add_zone($zone, [], "MASTER", 1);

					} else {
						if (defined($del_handler)) {
							die "defined script for powerdns_presigned_dnssec_del_script does not exist or is not executable: $del_handler" unless -e $del_handler && -x $del_handler;
							my $output = `$del_handler "$zone_name" 2>&1`;

							my $status = $? >> 8;
							if ($status) {
								die "defined script for powerdns_presigned_dnssec_del_script ($del_handler) returned error status $status and the following output: $output";
							}
						}

						$self->database->remove_zone($zone);
					}
				} else {
					$self->sync_zone($zone, $fetched_records_for_zones->{$zone_name});
				}

				push @$changes_successful, $change_id;
				push @$changes_status, "OK";
				push @$changes_message, "";
			};

			if ($@) {
				my $errormessage = $@;
				$errormessage = Dumper($errormessage) if ref($errormessage);
				$self->soap->MarkUpdated($change_id, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
			}
		}

		$self->soap->MarkUpdatedBulk($changes_successful, $changes_status, $changes_message) if scalar(@$changes_successful) > 0;
	}
}

sub fetch_records_for_zones {
	my $self = shift;
	my $zones = shift;

	my $records = undef;
	my $zone_hash = {};

	my $zones_ret = $self->soap->GetZoneBulk($zones);
	die("error fetching zones") unless defined($zones_ret) && $zones_ret->result && ref($zones_ret->result) eq "ARRAY";

	foreach my $zone_struct (@{$zones_ret->result}) {
		die "bad return data from GetZoneBulk" unless defined($zone_struct) && ref($zone_struct) eq "HASH" &&
			defined($zone_struct->{"name"});

		if (defined($zone_struct->{"binaryzone"})) {
			my $binaryzone = $zone_struct->{"binaryzone"};
			die "bad format of binaryzone, should be a base64 encoded string" unless defined($binaryzone) && ref($binaryzone) eq '';
			chomp $binaryzone;

			my @binaryarray = map {
				my @arr = split(/ /, $_, 6);
				die("bad format of binaryzone: row doesn't have 6 space separated fields") unless scalar(@arr) == 6;
				{ id => $arr[0], label => $arr[1], class => $arr[2], ttl => $arr[3], type => $arr[4], rdata => $arr[5] }
			} split(/\n/, $binaryzone);

			$zone_hash->{$zone_struct->{"name"}} = \@binaryarray;
		} else {
			$zone_hash->{$zone_struct->{"name"}} = [];
		}
	}

	return $zone_hash;
}

sub sync_zone {
	my $self = shift;
	my $zone = shift;
	my $records = shift;

	if (scalar(@$records) > 0) {
		my $zone_type = defined($self->config->{"powerdns_zone_type"}) && $self->config->{"powerdns_zone_type"} eq "MASTER" ? "MASTER" : "NATIVE";
		$self->database->add_zone($zone, $records, $zone_type, 0, $self->config->{"powerdns_zone_nsec_format"});
	} else {
		$self->database->remove_zone($zone);
	}
}

sub updates_disabled {
	my $self = shift;

	my $ret = $self->soap->GetUpdatesDisabled();
	die("error fetching status of updates, got no or bad result from soap-server: " . Dumper($ret->result)) unless defined($ret) &&
		defined($ret->result) && $ret->result =~ /^\d+$/;
	return $ret->result;
}

sub add_server {
	my $self = shift;
	my $group = shift;

	$self->soap->AddNameserver($self->config->{"servername"} || die("you have to specify servername in config"), $group);
}

sub get_server {
	my $self = shift;

	my $ret = $self->soap->GetNameserver($self->config->{"servername"} || die("you have to specify servername in config"));
	die "error fetching nameserver from soap-server" unless defined($ret) && defined($ret->result) && ref($ret->result) eq '';
	return $ret->result;
}

sub remove_server {
	my $self = shift;

	$self->soap->DeleteNameserver($self->config->{"servername"} || die("you have to specify servername in config"));
}

sub enable_updates {
	my $self = shift;

	$self->soap->SetUpdatesDisabled(0);
}

sub disable_updates {
	my $self = shift;

	$self->soap->SetUpdatesDisabled(1);
}

sub full_reload_online {
	my $self = shift;

	$self->soap->ReloadAllZones();
}

sub full_reload_slavezones {
	my $self = shift;

	$self->soap->ReloadAllSlaveZones();
}

sub reload_updated_slavezones {
	my $self = shift;

	my $zones = $self->soap->GetChangedSlaveZones($self->config->{"servername"} || die("you have to specify servername in config"));
	die("error fetching updated slave zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	return if scalar(@$zones) == 0;

	my $changes = [];

	foreach my $zonerec (@$zones) {
		my $zonename = $zonerec->{"name"};

		my $zone;
		eval {
			$zone = $self->soap->GetSlaveZone($zonename);
			die("error fetching zone for $zonename") unless defined($zone) && $zone->result && ref($zone->result) eq "ARRAY";
			$zone = $zone->result;
			die("bad response from GetSlaveZone") unless scalar(@$zone) == 1;
			$zone = $zone->[0];

			die("error fetching zone for $zonename") unless !defined($zone) || (ref($zone) eq "HASH" && defined($zone->{"master"}));

			$self->sync_slave_zone($zonename, $zone);
			$self->soap->MarkSlaveZoneUpdated($zonerec->{"id"}, "OK", "");
		};

		if ($@) {
			my $exception = $@;
			if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode eq 'soap:LogicalError.ZoneNotFound') {
				$zone = undef;
				eval {
					$self->sync_slave_zone($zonename, undef);
					$self->soap->MarkSlaveZoneUpdated($zonerec->{"id"}, "OK", "");
				};

				if ($@) {
					my $errormessage = $@;
					$errormessage = Dumper($errormessage) if ref($errormessage);
					$self->soap->MarkSlaveZoneUpdated($zonerec->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
				}
			} else {
				my $errormessage = $exception;
				$errormessage = Dumper($errormessage) if ref($errormessage);
				$self->soap->MarkSlaveZoneUpdated($zonerec->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
			}
		}
	}
}

sub sync_slave_zone {
	my $self = shift;
	my $zonename = shift;
	my $slavezone = shift; # undef => remove, otherwise { master => masterip, tsig_secret => secret or undef }

	if (defined($slavezone)) {
		$self->database->add_slave_zone($zonename, $slavezone);
	} else {
		$self->database->remove_slave_zone($zonename);
	}
}

sub import_zonefile {
	my $self = shift;
	my $zone_origin = shift;
	my $zone_file = shift;

	$zone_origin =~ s/\.$//;

    my $zonefile = new Net::DNS::ZoneFile( $zone_file, [$zone_origin] );
	my $parsed_zone = $zonefile->read;

	my $zone = { name => $zone_origin };
	my $records = [];

	my $nsec_type = "NSEC";
	RECORD: foreach my $record (@$parsed_zone) {
		if ($record->type =~ /^NSEC/) {
			$nsec_type = "NSEC3" if $record->type eq "NSEC3";
			next RECORD;
		}

		my $label = $self->atomia_host_to_label($record->name, $zone_origin);
		my $rdata = $record->rdatastr;
		$rdata =~ s/;.*?$//msg;
		$rdata =~ s/\r?\n/ /msg;
		if ($record->type =~ /^(SOA|RRSIG|SRV|DNSKEY)$/i) {
			$rdata =~ s/[()]//g;
		}
		$rdata =~ s/\s+/ /g;

		push @$records, { label => $label, ttl => $record->ttl, class => $record->class, type => $record->type, rdata => $rdata };
	}

	$self->database->add_zone($zone, $records, "MASTER", 0, $nsec_type);
}

sub atomia_host_to_label {
	my $self = shift;
	my $name = shift;
	my $zone = shift;

	if ($name eq $zone) {
		return '@';
	} else {
		die("atomia_host_to_label called when name not in zone") unless $name =~ /$zone$/;
		return substr($name, 0, length($name) - length($zone) - 1);
	}
}

sub set_external_dnssec_keys {
	my $self = shift;
	my $keys_to_push = shift;

	my $external_keys_at_server = $self->soap->GetExternalDNSSECKeys();
	die("error fetching DNSSEC keyset, got no or bad result from soap-server") unless defined($external_keys_at_server) &&
		$external_keys_at_server->result && ref($external_keys_at_server->result) eq "ARRAY";
	$external_keys_at_server = $external_keys_at_server->result;

	my @keys_to_set = split /\n/, $keys_to_push;
	foreach my $key (@keys_to_set) {
		if (scalar(grep { $_->{"keydata"} eq $key } @$external_keys_at_server) == 0) {
			print "adding external DNSSEC key: $key\n";
			$self->soap->AddExternalDNSSECKey($key);
		}
	}

	foreach my $key (@$external_keys_at_server) {
		if (scalar(grep { $_ eq $key->{"keydata"} } @keys_to_set) == 0) {
			print "removing external DNSSEC key " . $key->{"id"} . ": " . $key->{"keydata"} . "\n";
			$self->soap->DeleteExternalDNSSECKey($key->{"id"});
		}
	}
}

1;

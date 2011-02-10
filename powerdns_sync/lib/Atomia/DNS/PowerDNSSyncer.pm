#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::PowerDNSSyncer;

use Moose;
use Config::General;
use SOAP::Lite;
use Data::Dumper;
use Atomia::DNS::PowerDNSDatabase;

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
		eval "sub SOAP::Transport::HTTP::Client::get_basic_credentials { return '$soap_username' => '$soap_password' }";
	}

	my $soap = SOAP::Lite
		->  uri('urn:Atomia::DNS::Server')
		->  proxy($soap_uri, timeout => $self->config->{"soap_timeout"} || 600)
		->  on_fault(sub {
				my ($soap, $res) = @_;
				die((ref($res) && UNIVERSAL::isa($res, 'SOAP::SOM')) ? $res : ("got fault of type transport error: " . $soap->transport->status));
			});

	die("error instantiating SOAP::Lite") unless defined($soap);

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

	my $keyset = $self->soap->GetDNSSECKeys();
	die("error fetching DNSSEC keyset, got no or bad result from soap-server") unless defined($keyset) &&
		$keyset->result && ref($keyset->result) eq "ARRAY";
	$keyset = $keyset->result;

	$self->database->sync_keyset($keyset);
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

				$self->sync_zone($zone, $fetched_records_for_zones->{$zone->{"name"}});

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
		$self->database->add_zone($zone, $records);
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

			push @$changes, $zonerec->{"id"};
		};

		if ($@) {
			my $exception = $@;
			if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode eq 'soap:LogicalError.ZoneNotFound') {
				$zone = undef;
				push @$changes, $zonerec->{"id"};
	                } else {
				die $exception;
			}
		}

		die("error fetching zone for $zonename") unless !defined($zone) || (ref($zone) eq "HASH" && defined($zone->{"master"}));
		$self->sync_slave_zone($zone);
	}

	foreach my $change (@$changes) {
		$self->soap->MarkSlaveZoneUpdated($change, "OK", "");
	}
}

sub sync_slave_zone {
	my $self = shift;
	my $slavezone = shift; # undef => remove, otherwise { master => masterip }
}

1;

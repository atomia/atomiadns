#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::Syncer;

use Moose;
use Config::General;
use SOAP::Lite;
use BerkeleyDB;
use Data::Dumper;

has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");
has 'bdb_environment' => (is => 'rw', isa => 'Any', default => undef);
has 'bdb_environment_path' => (is => 'rw', isa => 'Any', default => undef);
has 'soap' => (is => 'rw', isa => 'Any', default => undef);

sub BUILD {
        my $self = shift;

	my $conf = new Config::General($self->configfile);
        die("config not found at $self->configfile") unless defined($conf);
        my %config = $conf->getall;
        $self->config(\%config);

	my $bdb_path = $self->bdb_environment_path ? $self->bdb_environment_path : $self->config->{"bdb_environment_path"};
	die("you have to either pass a path in the bdb_environment_path parameter or set bdb_environment_path in the config") unless defined($bdb_path);

	my $env = new BerkeleyDB::Env
		-Home   => $bdb_path,
		-Flags  => DB_INIT_TXN | DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_LOG | DB_CREATE;

	die("error creating bdb environment") unless defined($env);

	$self->bdb_environment($env);

	my $soap_uri = $self->config->{"soap_uri"} || die("soap_uri not specified in " . $self->configfile);
	my $soap = SOAP::Lite
		->  uri('urn:Atomia::DNS::Server')
		->  proxy($soap_uri)
		->  on_fault(sub {
				my ($soap, $res) = @_;
				die("got fault of type " . (ref($res) ? $res->faultcode : "transport error") . ": " . (ref($res) ? $res->faultstring : $soap->transport->status));
			});

	die("error instantiating SOAP::Lite") unless defined($soap);

	$self->soap($soap);
};

sub open_bdb {
	my $self = shift;
	my $name = shift;
	my $type = shift;
	my $truncate = shift;

	my $db;

	if ($type eq "Hash") {
		$db  = new BerkeleyDB::Hash
				-Filename       => $self->config->{"bdb_filename"} || die("you have to set bdb_filename"),
				-Subname        => $name,
				-Env            => $self->bdb_environment,
				-Flags          => DB_CREATE,
				-Property       => DB_DUP | DB_DUPSORT;
	} elsif ($type eq "Btree") {
		$db  = new BerkeleyDB::Btree
				-Filename       => $self->config->{"bdb_filename"} || die("you have to set bdb_filename"),
				-Subname        => $name,
				-Env            => $self->bdb_environment,
				-Flags          => DB_CREATE,
				-Property       => DB_DUP | DB_DUPSORT;
	} else {
		die("unsupported bdb-type, should not happen");
	}

	die("error opening/creating $name") unless defined($db);

	$self->truncate_bdb($db, $name) if defined($truncate) && $truncate == 1;

	return $db;
}

sub truncate_bdb {
	my $self = shift;
	my $db = shift;
	my $name = shift;

	my $count;
	$db->truncate(\$count) == 0 || die("error truncating $name");
}

sub full_reload_offline {
	my $self = shift;
	my $timestamp = shift;

	my ($db_zone, $db_client, $db_xfr, $db_data);

	eval {
		$db_zone = $self->open_bdb("dns_zone", "Btree", 1);
		$db_client = $self->open_bdb("dns_client", "Hash", 1);
		$db_xfr = $self->open_bdb("dns_xfr", "Hash", 1);
		$db_data = $self->open_bdb("dns_data", "Hash", 1);

		my $zones = $self->sync_all_zones($db_zone, $timestamp);
		$self->sync_records($db_data, $db_xfr, $zones);
	};

	if ($@) {
		print "Caught exception in full_reload_offline: $@\n";
	}

	$db_zone->db_close() if defined($db_zone);
	$db_client->db_close() if defined($db_client);
	$db_xfr->db_close() if defined($db_xfr);
	$db_data->db_close() if defined($db_data);
}

sub reload_updated_zones {
	my $self = shift;

	my ($db_zone, $db_xfr, $db_data, $db_client);

	eval {
		$db_zone = $self->open_bdb("dns_zone", "Btree", 0);
		$db_xfr = $self->open_bdb("dns_xfr", "Hash", 0);
		$db_data = $self->open_bdb("dns_data", "Hash", 0);
		$db_client = $self->open_bdb("dns_client", "Hash", 1);

		$self->sync_updated_zones($db_zone, $db_data, $db_xfr);
	};

	if ($@) {
		print "Caught exception in reload_updated: $@\n";
	}

	$db_zone->db_close() if defined($db_zone);
	$db_xfr->db_close() if defined($db_xfr);
	$db_data->db_close() if defined($db_data);
	$db_client->db_close() if defined($db_client);
}

sub sync_all_zones {
	my $self = shift;
	my $db_zone = shift;
	my $timestamp = shift;

	my $zones = $self->soap->GetAllZones();
	die("error fetching all zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	foreach my $zone (@$zones) {
		die("bad zone fetched") unless defined($zone) && ref($zone) eq "HASH";
		die("fetched zone.id had bad format") unless defined($zone->{"id"}) && $zone->{"id"} =~ /^\d+$/;
		die("fetched zone.name had bad format") unless defined($zone->{"name"}) && length($zone->{"name"}) > 0;

		$zone->{"changetime"} = $timestamp;

		die("error storing " . $zone->{"name"}) unless $db_zone->db_put(scalar(reverse($zone->{"name"})), "") == 0;
	}

	return $zones;
}

sub sync_updated_zones {
	my $self = shift;
	my $db_zone = shift;
	my $db_data = shift;
	my $db_xfr = shift;

	my $zones = $self->soap->GetChangedZones($self->config->{"servername"} || die("you have to specify servername in config"));
	die("error fetching updated zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	foreach my $zone (@$zones) {
		my $transaction = undef;
		my $change_id = undef;

		eval {
			$change_id = $zone->{"id"} || die("bad data from GetUpdatedZones, id not specified");

			$transaction = $self->bdb_environment->txn_begin() || die("error starting transaction");
			$self->remove_records($db_data, $db_xfr, $zone->{"name"} || die("bad data from GetUpdatedZones, zone not specified"));
			my $num_records = $self->sync_records($db_data, $db_xfr, [ $zone ]);
			$self->sync_zone($db_zone, $zone->{"name"}, $num_records);
			$transaction->txn_commit() == 0 || die("error commiting transaction");

			$self->soap->MarkUpdated($change_id, "OK", "");
		};

		if ($@) {
			my $abort_ret = 0;
			my $errormessage = $@;

			eval {
				$abort_ret = $transaction->txn_abort() if defined($transaction);
			};

			if ($@ && !$@ =~ /Transaction is already closed/) {
				$abort_ret = -1;
			}

			$self->soap->MarkUpdated($change_id, "ERROR", $errormessage);
			die("error performing rollback") unless $abort_ret == 0;
		}
	}
}

sub sync_records {
	my $self = shift;
	my $db_data = shift;
	my $db_xfr = shift;
	my $zones = shift;

	my $synced_records = 0;

	foreach my $zone (@$zones) {
		my $records = $self->fetch_records_for_zone($zone->{"name"});

		my %labels_seen;
		foreach my $record (@$records) {
			$record->{"rdata"} =~ s/%serial/$zone->{"changetime"}/g if $record->{"type"} eq "SOA";

			my $zonename  = $zone->{"name"};
			my $label = $record->{"label"};
			unless (exists($labels_seen{$label})) {
				$db_xfr->db_put($zonename, $label) == 0 || die("error storing db_xfr record for $label.$zonename");
				$labels_seen{$label} = 1;
			}

			$db_data->db_put("$zonename $label",
				$record->{"id"} . " $label " . $record->{"ttl"} . " " . $record->{"type"} .
				" " . $record->{"rdata"}) == 0 || die("error storing record for $label.$zonename");
		}

		$synced_records += scalar(@$records);
	}

	return $synced_records;
}

sub fetch_records_for_zone {
	my $self = shift;
	my $zonename = shift;

	my $zone = $self->soap->GetZone($zonename);
	die("error fetching zone for $zonename") unless defined($zone) && $zone->result && ref($zone->result) eq "ARRAY";

	my @records = map { @{$_->{"records"}} } @{$zone->result};
	return \@records;
}

sub sync_zone {
	my $self = shift;
	my $db_zone = shift;
	my $zonename = shift;
	my $num_records = shift;

	my $zone_key = scalar(reverse($zonename));

	if ($num_records > 0) {
		my $buf;
		my $status = $db_zone->db_get($zone_key, $buf);
		die ("error adding zone to db_zone") unless $status == 0 || $db_zone->db_put($zone_key, "") == 0;
	} else {
		my $status = $db_zone->db_del($zone_key);
		die ("error removing zone from db_zone") unless $status == 0 || $status == DB_NOTFOUND;
	}
}

sub remove_records {
	my $self = shift;
	my $db_data = shift;
	my $db_xfr = shift;
	my $zonename = shift;

	my $cursor = $db_xfr->db_cursor() || die("error getting cursor for db_xfr");

	my $value;
	my $status = $cursor->c_get($zonename, $value, DB_SET);
	die("error fetching first value from db_xfr for $zonename") unless $status == 0 || $status == DB_NOTFOUND;

	while ($status == 0) {
		my $del_record_status = $db_data->db_del("$zonename $value");
		die("error removing record for $zonename") unless $del_record_status == 0 || $del_record_status == DB_NOTFOUND;

		$status = $cursor->c_get($zonename, $value, DB_NEXT_DUP);
		die("error fetching next value from db_xfr for $zonename") unless $status == 0 || $status == DB_NOTFOUND;
	}

	my $del_xfr_status = $db_xfr->db_del($zonename);
	die("error removing db_xfr-records for $zonename") unless $del_xfr_status == 0 || $del_xfr_status == DB_NOTFOUND;

	$cursor->c_close() == 0 || die("error closing cursor");
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

	$self->soap->AddNameserver($self->config->{"servername"} || die("you have to specify servername in config"));
}

sub remove_server {
	my $self = shift;

	$self->soap->DeleteNameserver($self->config->{"servername"} || die("you have to specify servername in config"));
}

sub enable_updates {
	my $self = shift;

	$self->soap->SetUpdatesDisabled(1);
}

sub disable_updates {
	my $self = shift;

	$self->soap->SetUpdatesDisabled(0);
}

sub full_reload_online {
	my $self = shift;

	$self->soap->ReloadAllZones();
}

1;

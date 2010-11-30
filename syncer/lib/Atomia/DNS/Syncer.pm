#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::Syncer;

use Moose;
use Config::General;
use SOAP::Lite;
use BerkeleyDB;
use Data::Dumper;
use File::Basename;
use File::Temp;

has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");
has 'bdb_environment' => (is => 'rw', isa => 'Any', default => undef);
has 'bdb_environment_path' => (is => 'rw', isa => 'Any', default => undef);
has 'soap' => (is => 'rw', isa => 'Any', default => undef);
has 'slavezones_config' => (is => 'rw', isa => 'Str', default => undef);
has 'slavezones_dir' => (is => 'rw', isa => 'Str', default => undef);
has 'rndc_path' => (is => 'rw', isa => 'Str', default => undef);

sub BUILD {
        my $self = shift;

	my $conf = new Config::General($self->configfile);
        die("config not found at $self->configfile") unless defined($conf);
        my %config = $conf->getall;
        $self->config(\%config);

	$self->slavezones_config($self->config->{"slavezones_config"});
	die("you have to specify slavezones_config as an existing file") unless defined($self->slavezones_config) && -f $self->slavezones_config;

	$self->slavezones_dir($self->config->{"slavezones_dir"});
	die("you have to specify slavezones_dir as an existing directory") unless defined($self->slavezones_dir) && -d $self->slavezones_dir;

	$self->rndc_path($self->config->{"rndc_path"});
	die("you have to specify rndc_path as an existing file") unless defined($self->rndc_path) && -f $self->rndc_path;

	my $bdb_path = $self->bdb_environment_path ? $self->bdb_environment_path : $self->config->{"bdb_environment_path"};
	die("you have to either pass a path in the bdb_environment_path parameter or set bdb_environment_path in the config") unless defined($bdb_path);

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
		->  proxy($soap_uri)
		->  on_fault(sub {
				my ($soap, $res) = @_;
				die((ref($res) && UNIVERSAL::isa($res, 'SOAP::SOM')) ? $res : ("got fault of type transport error: " . $soap->transport->status));
			});

	die("error instantiating SOAP::Lite") unless defined($soap);

	$self->soap($soap);
};

sub create_env {
	my $self = shift;

	my $bdb_path = $self->bdb_environment_path ? $self->bdb_environment_path : $self->config->{"bdb_environment_path"};
	die("you have to either pass a path in the bdb_environment_path parameter or set bdb_environment_path in the config") unless defined($bdb_path);

	my $env = new BerkeleyDB::Env
		-Home   => $bdb_path,
		-Flags  => DB_INIT_TXN | DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_LOG | DB_CREATE;

	die("error creating bdb environment") unless defined($env);

	$self->bdb_environment($env);
}

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
		$self->create_env();

		$db_zone = $self->open_bdb("dns_zone", "Btree", 1);
		$db_client = $self->open_bdb("dns_client", "Hash", 1);
		$db_xfr = $self->open_bdb("dns_xfr", "Hash", 1);
		$db_data = $self->open_bdb("dns_data", "Hash", 1);

		my $zones = $self->sync_all_zones($db_zone, $timestamp);
		$self->sync_records($db_data, $db_xfr, $zones);
		$self->sync_zone_transfers($db_client);
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
		$self->create_env();

		$db_zone = $self->open_bdb("dns_zone", "Btree", 0);
		$db_xfr = $self->open_bdb("dns_xfr", "Hash", 0);
		$db_data = $self->open_bdb("dns_data", "Hash", 0);
		$db_client = $self->open_bdb("dns_client", "Hash", 0);

		$self->sync_updated_zones($db_zone, $db_data, $db_xfr);
		$self->sync_zone_transfers($db_client);
	};

	if ($@) {
		my $exception = $@;
		$exception = Dumper($exception) if ref($exception);
		print "Caught exception in reload_updated: $exception\n";
	}

	$db_zone->db_close() if defined($db_zone);
	$db_xfr->db_close() if defined($db_xfr);
	$db_data->db_close() if defined($db_data);
	$db_client->db_close() if defined($db_client);
}

sub sync_zone_transfers {
	my $self = shift;
	my $db_client = shift;

	my $allowed_transfers = $self->soap->GetAllowedZoneTransfer();
	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers);
	$allowed_transfers = $allowed_transfers->result;
	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers) &&
		ref($allowed_transfers) eq "ARRAY";

	my $transaction = undef;

	eval {
		$transaction = $self->bdb_environment->txn_begin() || die("error starting transaction");

		$self->truncate_bdb($db_client, "dns_client");

		foreach my $allowed_transfer (@$allowed_transfers) {
			die("error storing item for allowing zone transfer") unless $db_client->db_put($allowed_transfer->{"zonename"}, $allowed_transfer->{"allowed_ip"}) == 0;
		}

		$transaction->txn_commit() == 0 || die("error commiting transaction");
	};

	if ($@) {
		my $abort_ret = 0;
		my $errormessage = $@;
		$errormessage = Dumper($errormessage) if ref($errormessage);

		eval {
			$abort_ret = $transaction->txn_abort() if defined($transaction);
		};

		if ($@ && !$@ =~ /Transaction is already closed/) {
			$abort_ret = -1;
		}

		die("error performing rollback in sync_zone_transfers due to exception: $errormessage") unless $abort_ret == 0;
		die("caught exception in sync_zone_transfers, and aborted transaction successfully: $errormessage");
	}
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

				$transaction = $self->bdb_environment->txn_begin() || die("error starting transaction");
				$self->remove_records($db_data, $db_xfr, $zone->{"name"} || die("bad data from GetUpdatedZones, zone not specified"));
				my $num_records = $self->sync_records($db_data, $db_xfr, [ $zone ], $fetched_records_for_zones);
				$self->sync_zone($db_zone, $zone->{"name"}, $num_records);
				$transaction->txn_commit() == 0 || die("error commiting transaction");

				push @$changes_successful, $change_id;
				push @$changes_status, "OK";
				push @$changes_message, "";
			};

			if ($@) {
				my $abort_ret = 0;
				my $errormessage = $@;
				$errormessage = Dumper($errormessage) if ref($errormessage);

				eval {
					$abort_ret = $transaction->txn_abort() if defined($transaction);
				};

				if ($@ && !$@ =~ /Transaction is already closed/) {
					$abort_ret = -1;
				}

				$self->soap->MarkUpdated($change_id, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
				die("error performing rollback") unless $abort_ret == 0;
			}
		}

		$self->soap->MarkUpdatedBulk($changes_successful, $changes_status, $changes_message) if scalar(@$changes_successful) > 0;
	}
}

sub sync_records {
	my $self = shift;
	my $db_data = shift;
	my $db_xfr = shift;
	my $zones = shift;
	my $prefetched_records = shift;

	my $synced_records = 0;

	foreach my $zone (@$zones) {
		my $records = defined($prefetched_records) && defined($prefetched_records->{$zone->{"name"}})
			? $prefetched_records->{$zone->{"name"}} : $self->fetch_records_for_zone($zone->{"name"});

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

	my $records = undef;
	eval {
		my $zone = $self->soap->GetZone($zonename);
		die("error fetching zone for $zonename") unless defined($zone) && $zone->result && ref($zone->result) eq "ARRAY";
		my @records = map { @{$_->{"records"}} } @{$zone->result};
		$records = \@records;
	};

	if ($@) {
		my $exception = $@;
		if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode eq 'soap:LogicalError.ZoneNotFound') {
			return [];
		} else {
			die $exception;
		}
	}
	
	die "error fetching zones" unless defined($records) && ref($records) eq "ARRAY";
	return $records;
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

	my $config_zones = $self->parse_slavezone_config();

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

		if (defined($zone)) {
			die("error fetching zone for $zonename") unless ref($zone) eq "HASH" && defined($zone->{"master"});
			$config_zones->{$zonename} = $zone->{"master"};
		} else {
			delete $config_zones->{$zonename};
		}
	}

	my $filename = $self->write_slavezone_tempfile($config_zones);
	$self->move_slavezone_into_place($filename);
	$self->signal_bind_reconfig();

	foreach my $change (@$changes) {
		$self->soap->MarkSlaveZoneUpdated($change, "OK", "");
	}
}

sub parse_slavezone_config {
	my $self = shift;

	open SLAVES, $self->slavezones_config || die "error opening " . $self->slavezones_config . ": $!";

	my $state = 'startofzone';
	my $zones = {};
	my $zone = undef;

	ROW: while (<SLAVES>) {
		next ROW if /^\s*$/;
		chomp;
		$_ =~ s/^\s+//g;

		if ($state eq 'startofzone') {
			if (/^zone\s+"([^"]*)"/) {
				$zone = $1;
				$state = 'masters';
			} else {
				die "bad format of " . $self->slavezones_config . ", expecting $state";
			}
		} elsif ($state eq 'masters') {
			my $slavepath = sprintf "%s/%s", $self->slavezones_dir, $zone;
			next ROW if /^(type\s+slave|file\s+"$slavepath");$/;

			if (/^masters\s+{([^}]*?);+};$/) {
				$zones->{$zone} = $1;
				$state = 'endofzone';
			} else {
				die "bad format of " . $self->slavezones_config . ", expecting $state";
			}
		} elsif ($state eq 'endofzone') {
			my $slavepath = sprintf "%s/%s", $self->slavezones_dir, $zone;
			next ROW if /^(type\s+slave|file\s+"$slavepath");$/;

			if ($_ eq '};') {
				$state = 'startofzone';
			} else {
				die "bad format of " . $self->slavezones_config . ", expecting $state";
			}
		} else {
			die "unknown state: $state";
		}
	}

	close SLAVES || die "error closing " . $self->slavezones_config . ": $!";

	return $zones;
}

sub write_slavezone_tempfile {
	my $self = shift;
	my $zones = shift;

	my $tempfile = File::Temp->new(TEMPLATE => 'atomiaslavesyncXXXXXXXX', SUFFIX => '.tmp', UNLINK => 0, DIR => dirname($self->slavezones_config)) || die "error creating temporary file: $!";

	foreach my $zone (keys %$zones) {
		printf $tempfile ("zone \"%s\" {\n\ttype slave;\n\tfile \"%s/%s\";\n\tmasters {%s;};\n};\n", $zone, $self->slavezones_dir, $zone, $zones->{$zone});
	}

	return $tempfile->filename;
}

sub move_slavezone_into_place {
	my $self = shift;
	my $tempfile = shift;

	rename($tempfile, $self->slavezones_config) || die "error moving temporary slavezone file into place: $!";
}

sub signal_bind_reconfig {
	my $self = shift;
	system($self->rndc_path . " reconfig") == 0 || die "error reloading bind using rndc reconfig";
}

sub event_chain {
	my $self = shift;

	my $event_chain = $self->config->{"change_event_chain"};
	if (defined($event_chain) && ref($event_chain) eq "HASH") {
		my $event_listener_subscribername = $event_chain->{"event_listener_subscribername"};
		die "change_event_chain defined without event_listener_subscribername" unless defined($event_listener_subscribername);

		my $event_listener_nameservergroup = $event_chain->{"event_listener_nameservergroup"};
		die "change_event_chain defined without event_listener_nameservergroup" unless defined($event_listener_nameservergroup);

		eval {
			$self->soap->GetNameserver($event_listener_subscribername);
		};

		if ($@) {
			my $exception = $@;

			if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode =~ /LogicalError.NameserverNotFound/) {
				$self->soap->AddNameserver($event_listener_subscribername, $event_listener_nameservergroup);
			} else {
				die $exception;
			}
		}

		my $update_chain = $event_chain->{"on_update"} || [];
		$update_chain = [ $update_chain ] if ref($update_chain) eq '';

		my $delete_chain = $event_chain->{"on_delete"} || [];
		$delete_chain = [ $delete_chain ] if ref($delete_chain) eq '';

		my $zones = $self->soap->GetChangedZones($event_listener_subscribername);
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
				my $change_id = undef;

				eval {
					$change_id = $zone->{"id"} || die("bad data from GetUpdatedZones, id not specified");
					my $zone_name = $zone->{"name"};
					my $records = $fetched_records_for_zones->{$zone_name};
					die "bad data in fetched_records_for_zones" unless defined($records) && ref($records) eq "ARRAY";

					if (scalar(@$records) > 0) {
						foreach my $listener (@$update_chain) {
							die "defined listener for update chain does not exist or is not executable: $listener" unless -e $listener && -x $listener;
							my $output = `$listener "$zone_name" 2>&1`;

							my $status = $? >> 8;
							if ($status) {
								die "listener for update chain ($listener) returned error status $status and the following output: $output";
							}
						}
					} else {
						foreach my $listener (@$delete_chain) {
							die "defined listener for delete chain does not exist or is not executable: $listener" unless -e $listener && -x $listener;
							my $output = `$listener "$zone_name" 2>&1`;

							my $status = $? >> 8;
							if ($status) {
								die "listener for delete chain ($listener) returned error status $status and the following output: $output";
							}
						}
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

				$self->soap->MarkUpdatedBulk($changes_successful, $changes_status, $changes_message) if scalar(@$changes_successful) > 0;
			}
		}
	}
}

1;

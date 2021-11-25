#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::Syncer;

use Moose;
use Config::General;
use SOAP::Lite;
use Data::Dumper;
use File::Basename;
use File::Temp;
use MIME::Base64;

has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");
has 'soap' => (is => 'rw', isa => 'Any', default => undef);
has 'slavezones_config' => (is => 'rw', isa => 'Str');
has 'slavezones_dir' => (is => 'rw', isa => 'Str');
has 'rndc_path' => (is => 'rw', isa => 'Str');
has 'bind_user' => (is => 'rw', isa => 'Str');
has 'tsig_config' => (is => 'rw', isa => 'Str');
has 'zones_dir' => (is => 'rw', isa => 'Str');
has 'zone_file_config' => (is => 'rw', isa => 'Str');
has 'base_config_dir' => (is => 'rw', isa => 'Str');
has 'dnssec_keys_dir' => (is => 'rw', isa => 'Str');

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

	$self->bind_user($self->config->{"bind_user"});
	die("you have to specify bind_user") unless defined($self->bind_user);

	$self->tsig_config($self->config->{"tsig_config"});
	die("you have to specify tsig_config as an existing file") unless defined($self->tsig_config) && -f $self->tsig_config;
	
	$self->zones_dir($self->config->{"zones_dir_base_path"});
	die("you have to specify zone directory base path") unless defined($self->zones_dir) && -d $self->zones_dir;

	$self->zone_file_config($self->config->{"zone_file_local_conf_path"});
	die("you have to specify named.conf.local path") unless defined($self->zone_file_config) && -f $self->zone_file_config;
	
	$self->base_config_dir($self->config->{"base_config_dir"});
	die("you have to specify base_config_dir path") unless defined($self->base_config_dir) && -d $self->base_config_dir;

	$self->dnssec_keys_dir($self->config->{"dnssec_keys_dir"});
	die("you have to specify dnssec_keys_dir path") unless defined($self->dnssec_keys_dir) && -d $self->dnssec_keys_dir;

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

sub full_reload_offline {
	my $self = shift;
	my $timestamp = shift;

	eval {

		my $zones = $self->sync_all_zones($timestamp);
		$self->sync_records($zones);
		$self->sync_zone_transfers();
	};

	if ($@) {
		print "Caught exception in full_reload_offline: $@\n";
	}
}

sub reload_updated_zones {
	my $self = shift;

	eval {

		$self->sync_updated_zones();
		$self->sync_zone_transfers();

	};

	if ($@) {
		my $exception = $@;
		$exception = Dumper($exception) if ref($exception);
		print "Caught exception in reload_updated: $exception\n";
	}
}

sub sync_zone_transfers {
	my $self = shift;

	if ($self->use_tsig_keys_for_master_zones()) {
		return;
	}

	my $allowed_transfers = $self->soap->GetAllowedZoneTransfer();

	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers);
	$allowed_transfers = $allowed_transfers->result;
	die "bad data returned from soap-server for GetAllowedZoneTransfer" unless defined($allowed_transfers) &&
	ref($allowed_transfers) eq "ARRAY";

	my $allowed_zones = {};
	foreach my $allowed_transfer(@$allowed_transfers){
		my $zonename = $allowed_transfer->{"zonename"};

		if(!defined($allowed_zones->{$zonename})){
			$allowed_zones->{$zonename} = [];
		}

		push @{$allowed_zones->{$zonename}}, $allowed_transfer->{"allowed_ip"};
	}

		
	foreach my $zonename (keys %$allowed_zones) {
		eval {
			my $sub_zonefile = $self->get_zone_config_file($zonename);
			my $zones = $self->parse_zone_config($sub_zonefile);
			my $allowed_ips = $allowed_zones->{$zonename};

			foreach my $ip(@$allowed_ips) {
				if (index($zones->{$zonename}, "$ip;") == -1) {
					$zones->{$zonename} = $zones->{$zonename}. $ip . ";" ;
				} 
			}	

			my $filename = $self->write_zone_tempfile($zones);
			$self->move_zone_into_place($filename, $sub_zonefile);

		};
	}
	if ($@) {
		my $abort_ret = 0;
		my $errormessage = $@;
		$errormessage = Dumper($errormessage) if ref($errormessage);

		die("caught exception in sync_zone_transfers: $errormessage");
	}

	$self->signal_bind_reconfig();

}

sub sync_all_zones {
	my $self = shift;
	my $timestamp = shift;

	my $zones = $self->soap->GetAllZones();
	die("error fetching all zones, got no or bad result from soap-server") unless defined($zones) &&
	$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	$self->clear_file($self->zone_file_config);

	my $zones_mapping_to_files = {};

	foreach my $zone (@$zones) {
		die("bad zone fetched") unless defined($zone) && ref($zone) eq "HASH";
		die("fetched zone.id had bad format") unless defined($zone->{"id"}) && $zone->{"id"} =~ /^\d+$/;
		die("fetched zone.name had bad format") unless defined($zone->{"name"}) && length($zone->{"name"}) > 0;

		$zone->{"changetime"} = $timestamp;

		my $sub_zonefile = $self->get_zone_config_file($zone->{"name"});

		if (!defined($zones_mapping_to_files->{$sub_zonefile}))
		{
			$zones_mapping_to_files->{$sub_zonefile} = [];
		}

		push @{$zones_mapping_to_files->{$sub_zonefile}}, $zone;
	}

	foreach my $sub_zonefile (keys %$zones_mapping_to_files) {	
		
		my @zones = @{$zones_mapping_to_files->{$sub_zonefile}};

		my $config_created = $self->create_zone_config_file($sub_zonefile);

		if ($config_created){
			$self->add_include_string_into_config($sub_zonefile);
		}
		
		my $parsed_zones = $self->parse_zone_config($sub_zonefile);

		foreach my $zone (@zones)
		{
			my $zonename = $zone->{"name"};
			$parsed_zones->{$zonename} = "";
		}

		my $filename = $self->write_zone_tempfile($parsed_zones);
		$self->move_zone_into_place($filename, $sub_zonefile);
	}

	$self->signal_bind_reconfig();
	return $zones;
}

sub sync_updated_zones {
	my $self = shift;

	my $zones_batch_size = 10000;

	if (defined($self->config->{"changed_zones_batch_size"})) {
		$zones_batch_size = $self->config->{"changed_zones_batch_size"};
	}

	my $zones;

	if ($self->use_tsig_keys_for_master_zones()) {
		$zones = $self->soap->GetChangedZonesBatchWithTSIG($self->config->{"servername"} || die("you have to specify servername in config"), 10000);
		die("error fetching updated zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	}
	else {
		$zones = $self->soap->GetChangedZonesBatch($self->config->{"servername"} || die("you have to specify servername in config"), 10000);
		die("error fetching updated zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	}

	die("error fetching updated zones, got no or bad result from soap-server") unless defined($zones) &&
		$zones->result && ref($zones->result) eq "ARRAY";
	$zones = $zones->result;

	my $changes_to_keep = [];
	my $changes_to_keep_name = [];
	my $zones_mapping_to_files = {};

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
		my $sub_zonefile = $self->get_zone_config_file($zone->{"name"});
		
		if (!defined($zones_mapping_to_files->{$sub_zonefile}))
		{
			$zones_mapping_to_files->{$sub_zonefile} = [];
		}

		push @{$zones_mapping_to_files->{$sub_zonefile}}, $zone;
	}

	if (scalar(@$changes_to_keep) > 0) {
		$self->soap->MarkAllUpdatedExceptBulk($changes_to_keep_name, $changes_to_keep);
	}

	foreach my $sub_zonefile (keys %$zones_mapping_to_files) {

		my @batch = @{$zones_mapping_to_files->{$sub_zonefile}};

		my @get_zone_bulk_arg = map { $_->{"name"} } @batch;
		my $fetched_records_for_zones = $self->fetch_records_for_zones(\@get_zone_bulk_arg);

		my $changes_successful = [];
		my $changes_status = [];
		my $changes_message = [];

		my $config_created = $self->create_zone_config_file($sub_zonefile);

		if($config_created){
			$self->add_include_string_into_config($sub_zonefile);
		}

		my $old_zones = $self->parse_zone_config($sub_zonefile);

		foreach my $zone (@batch) {

			my $change_id = undef;

			eval {
				$change_id = $zone->{"id"} || die("bad data from GetUpdatedZones, id not specified");
				$self->remove_records($zone->{"name"} || die("bad data from GetUpdatedZones, zone not specified"));
				my $num_records = $self->sync_records([ $zone ], $fetched_records_for_zones);
				my $zonename = $zone->{"name"};

				if ($self->use_tsig_keys_for_master_zones()) {
					my %zone_hash = %$zone;
					$zone_hash{tsigkeyname} = $zone->{"tsigkeyname"};
					$zone = \%zone_hash;
				}

				if ($num_records > 0) {
					if (!$old_zones->{$zonename}) {
						$old_zones->{$zonename} = "";

						my $current_active_key = $self->get_current_active_key();

						if (defined($current_active_key) && defined($self->config->{"dnssec_public_key"})) {

							my $zone_dnssec_file_name = $self->get_zone_dnssec_filename($zonename);
							die "Both dnssec_public_key and  dnssec_keytag should be defined" if !defined($zone_dnssec_file_name);

							my $zonedir = $self->dnssec_keys_dir . "/" . substr($zonename, 0, 2);
								
							if ( !-d $zonedir ) {
								mkdir $zonedir or die "Failed to create path: $zonedir";
							}

							my $key_file = "$zonedir/$zone_dnssec_file_name.key";
							my $private_file = "/$zonedir/$zone_dnssec_file_name.private";

							open(my $zf, '>', $key_file) or die $!;
							print $zf "$zonename\. IN DNSKEY " . $self->config->{"dnssec_public_key"};
							close $zf;

							open(my $zf1, '>', $private_file) or die $!;
							print $zf1 $current_active_key->{"keydata"};
							close $zf1;

							$self->add_dnssec_files_priviliges($private_file, $key_file);

						}

						if ($self->use_tsig_keys_for_master_zones()) {
							$old_zones->{$zonename . "-key"} = $zone->{"tsigkeyname"};
						}
					}
				} else {
					delete $old_zones->{$zonename};

					my $zone_dnssec_file_name = $self->get_zone_dnssec_filename($zonename);
					die "Both dnssec_public_key and  dnssec_keytag should be defined" if !defined($zone_dnssec_file_name);
					my $subdir = substr($zonename, 0, 2);

					my $key_file = $self->dnssec_keys_dir . "/$subdir/$zone_dnssec_file_name.key";
					my $private_file = $self->dnssec_keys_dir . "/$subdir/$zone_dnssec_file_name.private";

					unlink($key_file) if ( -f $key_file);
					unlink($private_file) if ( -f $private_file);

					my $zone_records_file = $self->zones_dir . "/$subdir/$zonename";

					unlink($zone_records_file . "\.signed") if ( -f $zone_records_file . "\.signed");
					unlink($zone_records_file . "\.jbk") if ( -f $zone_records_file . "\.jbk");
					unlink($zone_records_file . "\.signed\.jnl") if ( -f $zone_records_file . "\.signed\.jnl");
					unlink($zone_records_file . "\.jnl") if ( -f $zone_records_file . "\.jnl");
				}

				push @$changes_successful, $change_id;
				push @$changes_status, "OK";
				push @$changes_message, "";
			};

			if ($@) {
				my $abort_ret = 0;
				my $errormessage = $@;
				$errormessage = Dumper($errormessage) if ref($errormessage);
				$self->soap->MarkUpdated($change_id, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
			}
		}

		my $filename = $self->write_zone_tempfile($old_zones);
		$self->move_zone_into_place($filename, $sub_zonefile);

		$self->soap->MarkUpdatedBulk($changes_successful, $changes_status, $changes_message) if scalar(@$changes_successful) > 0;
	}

	$self->signal_bind_reconfig();
}

sub get_zone_dnssec_filename {
	my $self = shift;
	my $zonename = shift;

	my $zone_dnssec_file_name = undef;
	
	if (defined($self->config->{"dnssec_public_key"}) && defined($self->config->{"dnssec_keytag"})) {
		my $dnssec_public_key =$self->config->{"dnssec_public_key"};
		my @dnssec_public_key_elements = split ' ', $dnssec_public_key;
		my $dnssec_keytag = $self->config->{"dnssec_keytag"};
		$zone_dnssec_file_name = "K$zonename\." . "+00" . $dnssec_public_key_elements[2] . "+". $dnssec_keytag;
	}

	return $zone_dnssec_file_name;
}

sub sync_records {
	my $self = shift;
	my $zones = shift;
	my $prefetched_records = shift;

	my $synced_records = 0;

	foreach my $zone (@$zones) {
		my $records = [];

		if (defined($self->config->{"zone_records_batch_size"})) {
			my $records_batch = [];
			my $offset = 0;
			my $limit = $self->config->{"zone_records_batch_size"};

			do { 
				$records_batch = $self->fetch_limited_num_records_for_zone($zone->{"name"}, $limit, $offset);
				$offset += $limit;
				push @$records, @$records_batch if (scalar(@$records_batch) > 0);
			} while (scalar(@$records_batch) > 0);
		}
		else {
			if (defined($prefetched_records) && defined($prefetched_records->{$zone->{"name"}})) {
				$records = $prefetched_records->{$zone->{"name"}};
			}
			else {
				my $records = $self->fetch_records_for_zone($zone->{"name"});
			}
		}

		my $record_order = [];
		my $idx = 1;

		foreach my $record (@$records) {
			if ($record->{"type"} eq "SOA") {
				$record->{"rdata"} =~ s/%serial(.*)/($zone->{"changetime"}$1)/g;
				@$record_order[0] = $record;
			}
			else {
				@$record_order[$idx] = $record;
				$idx++;
			}
		}

		my $record_string = "";

		foreach my $record (@$record_order) {
			my $record_data = $record->{"label"} . " " . $record->{"class"} . " " . $record->{"ttl"} . " " . $record->{"type"} ." ". $record->{"rdata"};
			$record_string = $record_string . $record_data . "\n";
		}

		my $zone_records_path = $self->get_zone_record_path($zone->{"name"});

		if (scalar(@$records) > 0)
		{
			open(my $zf, '>', $zone_records_path) or die $!;
			print $zf $record_string;
			close($zf);
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

sub fetch_limited_num_records_for_zone {
	my $self = shift;
	my $zonename = shift;
	my $limit = shift;
	my $offset = shift;

	my $records = undef;
	eval {
		my $zone = $self->soap->GetZoneWithRecordsLimit($zonename, $limit, $offset);
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

sub remove_records {
	my $self = shift;
	my $zonename = shift;

	my $zone_records_path = $self->get_zone_record_path($zonename);

	eval {
		if ( -e $zone_records_path)
		{
			unlink($zone_records_path) or die "Can't remove zone file record $zone_records_path: $!";
		}
		else
		{
			die "File $zone_records_path doesn't exist";
		}
	};
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
	
	die("error fetching updated slave zones, got no or bad result from soap-server") unless defined($zones) && $zones->result && ref($zones->result) eq "ARRAY";
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

			if (/^masters\s*{([^}]*?);?\s*(key\s+([^}]*?);)?\s*};$/) {
				$zones->{$zone} = $1;
				$zones->{$zone."-key"} = $3;
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
		next if ($zone =~ /.*-key$/ );
		if (!defined($zones->{$zone."-key"})) {
			printf $tempfile ("zone \"%s\" {\n\ttype slave;\n\tfile \"%s/%s\";\n\tmasters {%s;};\n};\n", $zone, $self->slavezones_dir, $zone, $zones->{$zone});
		} else {
			printf $tempfile ("zone \"%s\" {\n\ttype slave;\n\tfile \"%s/%s\";\n\tmasters {%s key %s;};\n};\n", $zone, $self->slavezones_dir, $zone, $zones->{$zone}, $zones->{$zone."-key"});
		}
	}

	return $tempfile->filename;
}

sub move_slavezone_into_place {
	my $self = shift;
	my $tempfile = shift;

	rename($tempfile, $self->slavezones_config) || die "error moving temporary slavezone file into place: $!";

	if ($self->bind_user eq "bind") {
		system("chmod 640 " . $self->slavezones_config);
		system("chown root:bind " . $self->slavezones_config);
	}
	elsif ($self->bind_user eq "named") {
		system("chmod 640 " . $self->slavezones_config);
		system("chown root:named " . $self->slavezones_config);
	}
	else {
		die "Bind user doesn't exist";
	}
}

sub signal_bind_reconfig {
	my $self = shift;
	system($self->rndc_path . " reload") == 0 || die "error reloading bind using rndc reconfig";
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

sub use_tsig_keys_for_master_zones {
	my $self = shift;

	if (defined($self->config->{"use_tsig_for_master_zones"}) &&
			$self->config->{"use_tsig_for_master_zones"} eq "1") {		
		
		return 1;
	}

	return 0;
}

sub add_include_string_into_config {
	my $self = shift;
	my $sub_zonefile = shift;

	eval { 
		open(my $zf, '>>', $self->zone_file_config) or die $!;
		print $zf "include \"$sub_zonefile\";\n";
		close $zf;
	};
	if($@)
	{
		die "Couldn't write to " . $self->zone_file_config . ":". $@;
	}
}

sub get_zone_record_path {
	my $self = shift;
	my $zonename = shift;

	my $subdir = substr($zonename, 0, 2);

	my $zone_records_dir = $self->zones_dir . '/'. $subdir;

	if ( !-d $zone_records_dir ) {
		mkdir $zone_records_dir or die "Failed to create path: $zone_records_dir";

		if ($self->bind_user eq "bind") {
			system("chmod 740 " . $zone_records_dir);
			system("chown bind:bind " . $zone_records_dir);
		}
		elsif ($self->bind_user eq "named") {
			system("chmod 740 " . $zone_records_dir);
			system("chown root:named " . $zone_records_dir);
		} else {
			die "Bind user doesn't exist";
		}
	}

	my $zone_config_file_path = $zone_records_dir . "/" . $zonename;

	return $zone_config_file_path;

}

sub get_zone_config_file {

	my $self = shift;
	my $zonename = shift;

	my $zone_config_path = $self->base_config_dir . '/'. substr($zonename,0,1).".conf";

	return $zone_config_path;
}

sub create_zone_config_file {
	my $self = shift;
	my $zone_config_path = shift;

	if (! -f $zone_config_path)
	{
		open TEMP,'>',$zone_config_path or die $!;
		close TEMP;
		return 1;
	}

	return 0;
}

sub write_zone_tempfile {
	my $self = shift;
	my $zones = shift;

	my $tempfile = File::Temp->new(TEMPLATE => 'atomiazonessyncXXXXXXXX', SUFFIX => '.tmp', UNLINK => 0, DIR => dirname($self->zone_file_config)) || die "error creating temporary file: $!";

	foreach my $zone (keys %$zones) {
		next if ($zone =~ /.*-key$/ );
		my $zone_record_path = $self->get_zone_record_path($zone);

		my $allow_dnssec = '';

		if (defined($self->config->{"bind_sync_keys"}) && $self->config->{"bind_sync_keys"} eq "1") {
			my $key_dir = $self->dnssec_keys_dir . "/" . substr($zone, 0, 2);
			$allow_dnssec = "\n\tauto-dnssec maintain;\n\tinline-signing yes;\n\tkey-directory \"$key_dir\";";
		}

		if ($self->use_tsig_keys_for_master_zones()) {
			if (!defined($zones->{$zone."-key"})) {
				printf $tempfile ("zone \"%s\" {\n\ttype master;\n\tfile \"%s\";$allow_dnssec\n};\n", $zone, $zone_record_path);
			} else {
				printf $tempfile ("zone \"%s\" {\n\ttype master;\n\tfile \"%s\";$allow_dnssec\n\tallow-transfer {key %s;};\n};\n", $zone, $zone_record_path, $zones->{$zone."-key"});
			}
		} else {
			if( $zones->{$zone} eq "") {
				printf $tempfile ("zone \"%s\" {\n\ttype master;\n\tfile \"%s\";$allow_dnssec\n};\n", $zone, $zone_record_path);
			}
			else {
				printf $tempfile ("zone \"%s\" {\n\ttype master;\n\tfile \"%s\";$allow_dnssec\n\tallow-transfer {%s};\n};\n", $zone, $zone_record_path, $zones->{$zone});
			}
		}
	}

	return $tempfile->filename;
}

sub move_zone_into_place {
	my $self = shift;
	my $tempfile = shift;
	my $sub_zonefile = shift;

	rename($tempfile, $sub_zonefile) || die "error moving temporary zone file into place: $!";
	
	if ($self->bind_user eq "bind") {
		system("chmod 640 " . $sub_zonefile);
		system("chown root:bind " . $sub_zonefile);
	}
	elsif ($self->bind_user eq "named") {
		system("chmod 640 " . $sub_zonefile);
		system("chown root:named " . $sub_zonefile);
	} else {
		die "Bind user doesn't exist";
	}
}

sub clear_file {
	my $self = shift;
	my $path = shift;
	
	open my $zf, ">", $path;
	print $zf "";
	close $zf;
}

sub parse_zone_config {
	my $self = shift;
	my $sub_zonefile = shift;

	open (MASTERS, '<', $sub_zonefile) || die "error opening $sub_zonefile : $!";

	my $state = 'startofzone';
	my $zones = {};
	my $zone = undef;

	ROW: while (<MASTERS>) {
		next ROW if /^\s*$/;
		chomp;
		$_ =~ s/^\s+//g;
		if ($state eq 'startofzone') {
			if (/^zone\s+"([^"]*)"/) {
				$zone = $1;
				$zones->{$zone} = "";
				$state = 'allow-transfer';
			}
			else {
				die "bad format of " . $sub_zonefile . ", expecting $state";
			}
		}
		elsif ($state eq 'allow-transfer') {
			my $zone_record_path = $self->get_zone_record_path($zone);
			my $path = sprintf "%s", $zone_record_path;
			my $key_path = $self->dnssec_keys_dir . "/" . substr($zone, 0, 2);
			next ROW if /^(type\s+master|file\s+"$path"|auto-dnssec maintain|inline-signing yes|key-directory "$key_path");$/;

			if ($self->use_tsig_keys_for_master_zones()) {
				if (/^allow-transfer\s*{([^}]*?);?\s*(key\s+([^}]*?);)?\s*};$/) {
					$zones->{$zone} = $1;
					$zones->{$zone."-key"} = $3;
				} elsif ($_ eq '};'){
					$state = 'startofzone';
				} else {
					die "bad format of " . $sub_zonefile . ", expecting $state";
				}
			} else {
				if (/^allow-transfer\s+{([^}]*)\s*};$/) {
					$zones->{$zone} = $1;
				} elsif ($_ eq '};'){
					$state = 'startofzone';
				} else {
					die "bad format of " . $sub_zonefile . ", expecting $state";				
				}
			} 
		} else {
			die "unknown state: $state";
		}
	}

	close MASTERS || die "error closing " . $sub_zonefile . ": $!";

	return $zones;
}
sub reload_updated_tsig_keys {
	my $self = shift;

	my $change_table_tsig_keys = $self->soap->GetChangedTSIGKeys($self->config->{"servername"} || die("you have to specify servername in config"));
	die("error fetching updated tsig keys, got no or bad result from soap-server") unless defined($change_table_tsig_keys) &&
		$change_table_tsig_keys->result && ref($change_table_tsig_keys->result) eq "ARRAY";
	$change_table_tsig_keys = $change_table_tsig_keys->result;

	return if scalar(@$change_table_tsig_keys) == 0;

	my $config_tsig = $self->parse_tsig_config();

	foreach my $change_table_tsig_key (@$change_table_tsig_keys) {
		my $tsig_key_name = $change_table_tsig_key->{"name"};

		my $tsig_key_data;
		eval {
			$tsig_key_data = $self->soap->GetTSIGKey($tsig_key_name);
			die("error fetching tsig key data for $tsig_key_name") unless defined($tsig_key_data) && $tsig_key_data->result && ref($tsig_key_data->result) eq "ARRAY";
			$tsig_key_data = $tsig_key_data->result;
			die("bad response from GetTSIGKey") unless scalar(@$tsig_key_data) == 1;
			$tsig_key_data = $tsig_key_data->[0];

			die("error fetching tsig key data for $tsig_key_name") unless !defined($tsig_key_data) || (ref($tsig_key_data) eq "HASH" && defined($tsig_key_data->{"secret"}));

			if (defined($tsig_key_data)) {
				$config_tsig->{$tsig_key_name} = $tsig_key_data;
			} else {
				delete $config_tsig->{$tsig_key_name};
			}

			$self->soap->MarkTSIGKeyUpdated($change_table_tsig_key->{"id"}, "OK", "");
		};

		if ($@) {
			my $exception = $@;
			if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode eq 'soap:LogicalError.TSIGKeyNotFound') {
				eval {
					delete $config_tsig->{$tsig_key_name};
					$self->soap->MarkTSIGKeyUpdated($change_table_tsig_key->{"id"}, "OK", "");
				};

				if ($@) {
					my $errormessage = $@;
					$errormessage = Dumper($errormessage) if ref($errormessage);
					$self->soap->MarkTSIGKeyUpdated($change_table_tsig_key->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
				}
			} else {
				my $errormessage = $exception;
				$errormessage = Dumper($errormessage) if ref($errormessage);
				$self->soap->MarkTSIGKeyUpdated($change_table_tsig_key->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
			}
		}
	}

	my $filename = $self->write_tsig_tempfile($config_tsig);
	$self->move_tsig_into_place($filename);
	$self->signal_bind_reconfig();
}

sub parse_tsig_config {
	my $self = shift;

	open TSIG, $self->tsig_config || die "error opening " . $self->tsig_config . ": $!";

	my $state = 'startoftsig';
	my $keys = {};
	my $key = undef;

	ROW: while (<TSIG>) {
		next ROW if /^\s*$/;
		chomp;
		$_ =~ s/^\s+//g;

		if ($state eq 'startoftsig') {
			if (/^key\s+"([^"]*)"/) {
				$key = $1;
				$keys->{$key} = {};
				$keys->{$key}->{"name"} = $1;
				$state = 'keydata_alg';
			} else {
				die "bad format of " . $self->tsig_config . ", expecting $state";
			}
		} elsif ($state eq 'keydata_alg') {
			if (/^algorithm\s+([^}]*?);$/) {
				$keys->{$key}->{"algorithm"} = $1;
				$state = 'keydata_secret';
			} else {
				die "bad format of " . $self->tsig_config . ", expecting $state";
			}
		} elsif ($state eq 'keydata_secret') {
			if (/^secret\s+"([^}]*?)";$/) {
				$keys->{$key}->{"secret"} = $1;
				$state = 'endoftsig';
			} else {
				die "bad format of " . $self->tsig_config . ", expecting $state";
			}
		} elsif ($state eq 'endoftsig') {
			if ($_ eq '};') {
				$state = 'startoftsig';
			} else {
				die "bad format of " . $self->tsig_config . ", expecting $state";
			}
		} else {
			die "unknown state: $state";
		}
	}

	close TSIG || die "error closing " . $self->tsig_config . ": $!";

	return $keys;
}

sub write_tsig_tempfile {
	my $self = shift;
	my $keys = shift;


	my $tempfile = File::Temp->new(TEMPLATE => 'atomiaslavesyncXXXXXXXX', SUFFIX => '.tmp', UNLINK => 0, DIR => dirname($self->tsig_config)) || die "error creating temporary file: $!";

	foreach my $tsig_key (keys %$keys) {
		printf $tempfile ("key \"%s\" {\n\talgorithm %s;\n\tsecret \"%s\";\n};\n", $tsig_key, $keys->{$tsig_key}->{"algorithm"},$keys->{$tsig_key}->{"secret"});
	}

	return $tempfile->filename;
}

sub move_tsig_into_place {
	my $self = shift;
	my $tempfile = shift;

	rename($tempfile, $self->tsig_config) || die "error moving temporary tsig_config file into place: $!";

	if ($self->bind_user eq "bind") {
		system("chmod 640 " . $self->tsig_config);
		system("chown root:bind " . $self->tsig_config);
	}
	elsif ($self->bind_user eq "named") {
		system("chmod 640 " . $self->tsig_config);
		system("chown root:named " . $self->tsig_config);
	}
	else {
		die "Bind user doesn't exist";
	}
}

sub reload_updated_domainmetadata {
	my $self = shift;

	my $change_table_domain_ids = $self->soap->GetChangedDomainIDs($self->config->{"servername"} || die("you have to specify servername in config"));
	die("error fetching updated domain ids, got no or bad result from soap-server") unless defined($change_table_domain_ids) &&
		$change_table_domain_ids->result && ref($change_table_domain_ids->result) eq "ARRAY";
	$change_table_domain_ids = $change_table_domain_ids->result;

	return if scalar(@$change_table_domain_ids) == 0;

	my $config_zones = $self->parse_slavezone_config();
	my @processed_domains;

	foreach my $change_table_domain_id (@$change_table_domain_ids) {
		my $domainmetadata_id_and_domain_name = $change_table_domain_id->{"domain_id"};
		
		my @domainmetadata_id_and_domain_name_arr = split(',', $domainmetadata_id_and_domain_name);
		my $domainmetadata_id = $domainmetadata_id_and_domain_name_arr[0];
		my $domain_name = $domainmetadata_id_and_domain_name_arr[1];
		
		my $domainmetadata;
		eval {
			$domainmetadata = $self->soap->GetDomainMetaData($domainmetadata_id);

			die("error fetching domainmetata for $domainmetadata") unless defined($domainmetadata) && $domainmetadata->result && ref($domainmetadata->result) eq "ARRAY";
			$domainmetadata = $domainmetadata->result;
			die("bad response from GetDomainMetaData") unless scalar(@$domainmetadata) == 1;
			$domainmetadata = $domainmetadata->[0];

			die("error fetching domainmetadata for domainmetadata.id: $domainmetadata_id") unless !defined($domainmetadata) || (ref($domainmetadata) eq "HASH" && defined($domainmetadata->{"tsigkey_name"}));

			if ( !grep( /^$domain_name$/, @processed_domains ) ) {
				if (defined($domainmetadata)) {
					$config_zones->{$domain_name."-key"} = $domainmetadata->{"tsigkey_name"};
				} else {
					delete $config_zones->{$domain_name."-key"};
				}
				$self->soap->MarkDomainMetaDataUpdated($change_table_domain_id->{"id"}, "OK", "");
				push (@processed_domains, $domain_name);
			}
		};
		
		if ($@) {
			my $exception = $@;
			if (ref($exception) && UNIVERSAL::isa($exception, 'SOAP::SOM') && $exception->faultcode eq 'soap:LogicalError.DomainMetaDataNotFound') {
				eval {
					if ( !grep( /^$domain_name$/, @processed_domains ) ) {
						delete $config_zones->{$domain_name."-key"};
						$self->soap->MarkDomainMetaDataUpdated($change_table_domain_id->{"id"}, "OK", "");
						push (@processed_domains, $domain_name);
					}
				};

				if ($@) {
					my $errormessage = $@;
					$errormessage = Dumper($errormessage) if ref($errormessage);
					$self->soap->MarkDomainMetaDataUpdated($change_table_domain_id->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
				}
			} else {
				my $errormessage = $exception;
				$errormessage = Dumper($errormessage) if ref($errormessage);
				$self->soap->MarkDomainMetaDataUpdated($change_table_domain_id->{"id"}, "ERROR", $errormessage) unless defined($errormessage) && $errormessage =~ /got fault of type transport error/;
			}
		}
	}

	my $filename = $self->write_slavezone_tempfile($config_zones);
	$self->move_slavezone_into_place($filename);
	$self->signal_bind_reconfig();
}

sub sync_dnssec_keys {
	my $self = shift;

	if (!defined($self->config->{"bind_sync_keys"}) || $self->config->{"bind_sync_keys"} eq "0") {
		return;
	}

	my $new_private_key = $self->get_current_active_key();
	my $new_public_key = $self->config->{"dnssec_public_key"};

	if (!defined($new_private_key) || !defined($new_public_key)) {
		return;
	}

	my @private_keys_files = grep { -f } glob  $self->dnssec_keys_dir . "/*/*.private"; 
	my $changed = 0;

	foreach my $private_file (@private_keys_files) {
		eval {
			open my $fp, '<', $private_file or die "Can't open file $!";
			my $file_content = do { local $/; <$fp> };
			close $fp;
		
			if ((defined($new_private_key->{"keydata"})) && ($file_content ne $new_private_key->{"keydata"})) {

				my $key_file = $private_file;
				$key_file =~ s/private$/key/g;
		
				my $zonename = undef;
				if ($private_file =~ /K([^\+]*)/) {
					$zonename = $1;
					$zonename =~ s/\.$//g;
				}

				die ".key filename is not valid" if !defined($zonename);

				my $zone_dnssec_file_name = $self->get_zone_dnssec_filename($zonename);
				die "Both dnssec_public_key and  dnssec_keytag should be defined" if !defined($zone_dnssec_file_name);

				my $subdir = substr($zonename, 0, 2);
				my $new_key_file = $self->dnssec_keys_dir . "/$subdir/$zone_dnssec_file_name.key";
				my $new_private_file = $self->dnssec_keys_dir . "/$subdir/$zone_dnssec_file_name.private";

				die "The new key tag cannot be the same as the old one!" if (($new_key_file eq $key_file) || ($new_private_file eq $private_file));

				open $fp, '>', $new_private_file or die "Can't open file $!";
				print $fp $new_private_key->{"keydata"};
				close $fp;

				open my $fp1, '>', $new_key_file or die "Can't open file $!";
				print $fp1 "$zonename\. IN DNSKEY $new_public_key";
				close $fp1;

				$self->add_dnssec_files_priviliges($private_file, $key_file);

				unlink($key_file) if ( -f $key_file);
				unlink($private_file) if ( -f $private_file);
				
				my $zone_records_file = $self->zones_dir . "/$subdir/$zonename";

				unlink($zone_records_file . "\.signed") if ( -f $zone_records_file . "\.signed");
				unlink($zone_records_file . "\.jbk") if ( -f $zone_records_file . "\.jbk");
				unlink($zone_records_file . "\.signed\.jnl") if ( -f $zone_records_file . "\.signed\.jnl");
				unlink($zone_records_file . "\.jnl") if ( -f $zone_records_file . "\.jnl");

				$changed = 1;
			}
		};
		if ($@) {
			die "dnssec sync failed: $@";
		}
	}

	if ($changed) {
		$self->signal_bind_reconfig();
	}
}

sub add_dnssec_files_priviliges {
	my $self = shift;
	my $private_file = shift;
	my $key_file = shift;

	if ($self->bind_user eq "bind") {
		system("chmod 640 " . $key_file);
		system("chown root:bind " . $key_file);
		system("chmod 640 " . $private_file);
		system("chown root:bind " . $private_file);
	} elsif ($self->bind_user eq "named") {
		system("chmod 640 " . $key_file);
		system("chown root:named " . $key_file);	
		system("chmod 640 " . $private_file);
		system("chown root:named " . $private_file);
	} else {
			die "Bind user doesn't exist";
	}
}

sub get_current_active_key {
	my $self = shift;

	my $keyset = $self->soap->GetDNSSECKeys();
	die("error fetching DNSSEC keyset, got no or bad result from soap-server") unless defined($keyset) &&
		$keyset->result && ref($keyset->result) eq "ARRAY";
	$keyset = $keyset->result;

	my $activated_keys = [];
	foreach my $key (@$keyset) {
		if ($key->{"activated"} eq "1" && $key->{"keytype"} eq "KSK") {
			push @$activated_keys, $key;
		}
	}

	@$activated_keys = sort { $b->{"activated_at"} cmp $a->{"activated_at"}} @$activated_keys;

	my $current_active_key = undef;

    if (scalar(@$activated_keys) >= 1){
		$current_active_key = @$activated_keys[0];
	} 

	return $current_active_key;
}

1;

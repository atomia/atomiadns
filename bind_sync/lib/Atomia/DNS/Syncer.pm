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

has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/atomiadns.conf");
has 'soap' => (is => 'rw', isa => 'Any', default => undef);
has 'slavezones_config' => (is => 'rw', isa => 'Str');
has 'slavezones_dir' => (is => 'rw', isa => 'Str');
has 'rndc_path' => (is => 'rw', isa => 'Str');
has 'bind_user' => (is => 'rw', isa => 'Str');
has 'tsig_config' => (is => 'rw', isa => 'Str');

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
}

sub reload_updated_zones {
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

	my $zones;

	if (defined($self->config->{"use_tsig_keys"}) && $self->config->{"use_tsig_keys"} eq "1") {
		$zones = $self->soap->GetChangedSlaveZonesWithTSIG($self->config->{"servername"} || die("you have to specify servername in config"));
		die("error fetching updated slave zones, got no or bad result from soap-server") unless defined($zones) &&
		
		$zones->result && ref($zones->result) eq "ARRAY";
		$zones = $zones->result;
	}
	else {
		$zones = $self->soap->GetChangedSlaveZones($self->config->{"servername"} || die("you have to specify servername in config"));
		die("error fetching updated slave zones, got no or bad result from soap-server") unless defined($zones) &&
	
		$zones->result && ref($zones->result) eq "ARRAY";
		$zones = $zones->result;	
	}

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

			if (defined($self->config->{"use_tsig_keys"}) && $self->config->{"use_tsig_keys"} eq "1") {
				my %zone_hash = %$zone;
				$zone_hash{tsigkeyname} = $zonerec->{"tsigkeyname"};
				$zone = \%zone_hash;
			}

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
			$config_zones->{$zonename."-key"} = $zone->{"tsigkeyname"};
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
1;

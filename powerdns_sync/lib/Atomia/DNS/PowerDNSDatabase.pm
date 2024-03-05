#!/usr/bin/perl -w

package Atomia::DNS::PowerDNSDatabase;

use Moose;
use DBI;
use Digest::SHA qw(sha1);

has 'config' => (is => 'ro', isa => 'HashRef');
has 'conn' => (is => 'rw', isa => 'Object');
has 'nsec3_iterations' => (is => 'rw', isa => 'Int');
has 'nsec3_salt' => (is => 'rw', isa => 'Str');
has 'nsec3_salt_pres' => (is => 'rw', isa => 'Str');

sub BUILD {
	my $self = shift;
	$self->nsec3_iterations(defined($self->config->{"powerdns_nsec3_iterations"}) ? $self->config->{"powerdns_nsec3_iterations"} : 1);
	my $salt = $self->config->{"powerdns_nsec3_salt"} || "ab";
	die "powerdns_nsec3_salt should be one byte in hex format, like 7f" unless defined($salt) && $salt =~ /^[0-9A-F]{2}$/i;
	$self->nsec3_salt(chr(hex($salt)));
	$self->nsec3_salt_pres($salt);
}

sub validate_config {
	my $self = shift;
	my $config = shift;

	die("you have to specify powerdns_db_hostname") unless defined($config->{"powerdns_db_hostname"});
	die("you have to specify powerdns_db_username") unless defined($config->{"powerdns_db_username"});
	die("you have to specify powerdns_db_password") unless defined($config->{"powerdns_db_password"});
	die("you have to specify powerdns_db_database") unless defined($config->{"powerdns_db_database"});
}

sub dbi {
        my $self = shift;
        my $no_ping_check = shift;

        $self->validate_config($self->config);

        my $dbh = $self->conn;

        if (defined($dbh) && defined($no_ping_check) && $no_ping_check == 1) {
                return $dbh;
        }
        elsif (defined($dbh) && $dbh->ping) {
                return $dbh;
        } else {
                my $dbname = $self->config->{"powerdns_db_database"};
                my $dbhost = $self->config->{"powerdns_db_hostname"};
                my $dbuser = $self->config->{"powerdns_db_username"};
                my $dbpass = $self->config->{"powerdns_db_password"};
                my $dbport = $self->config->{"powerdns_db_port"} || 3306;

                my $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$dbport";
                my @conn_args = ($dsn, $dbuser, $dbpass, { PrintError => 0, PrintWarn => 0 });

                $dbh = DBI->connect(@conn_args);
                die("error connecting to $dbname") unless defined($dbh) && $dbh;

		$dbh->{"AutoCommit"} = 0;
		if ($dbh->{'AutoCommit'}) {
			die "error setting disabling autocommit";
		}

                $self->conn($dbh);
                return $dbh;
        }
}

sub encode_base32 {
	my $arg = shift;
	return '' unless defined($arg);    # mimic MIME::Base64

	$arg = unpack('B*', $arg);
	$arg =~ s/(.....)/000$1/g;
	my $l = length($arg);
	if ($l & 7) {
		my $e = substr($arg, $l & ~7);
		$arg = substr($arg, 0, $l & ~7);
		$arg .= "000$e" . '0' x (5 - length $e);
	}
	$arg = pack('B*', $arg);
	$arg =~ tr|\0-\37|A-Z2-7|;
	return $arg;
}

sub parse_record {
	my $self = shift;
	my $record = shift;
	my $nsec_type = shift;
	my $zone = shift;
	my $name = shift;

	my $content = $record->{"rdata"};
	my $type = $record->{"type"};
	my $ttl = $record->{"ttl"};
	my $label = $record->{"label"};
	my $ordername = '';

	if ($nsec_type eq 'NSEC') {
		$ordername = lc(join(" ", reverse(split(/\./, ($label eq '@' ? '' : $label)))));
	} elsif ($nsec_type eq 'NSEC3') {
		my $nsec3 = $label eq '@' ? $zone->{"name"} : lc($label . "." . $zone->{"name"});
		my @parts = split(/\./, $nsec3);
		$nsec3 = join("", map { pack("Ca*", length($_), $_) } @parts) . "\0";
		$nsec3 = sha1($nsec3, $self->nsec3_salt);

		for (my $idx = 0; $idx < $self->nsec3_iterations; $idx++) {
			$nsec3 = sha1($nsec3, $self->nsec3_salt);
		}

		$ordername = lc(encode_base32($nsec3));
	}

	$ordername = $self->dbi->quote($ordername);

	my $prio = "NULL";
	my $fqdn = $label eq '@' ? $name : $self->dbi->quote($label . "." . $zone->{"name"});
	my $auth = ($type eq 'NS' && $label ne '@') ? 0 : 1;

	if ($type eq "SOA") {
		$content =~ s/%serial/$zone->{"changetime"}/g;
		$content =~ s/\. / /g;
	} elsif ($type =~ /^(CNAME|MX|PTR|NS)$/) {
		$content = $content . "." . $zone->{"name"} unless $content =~ /\.$/;
		$content =~ s/\.$//;
	}

	if ($type =~ /^(MX|SRV)$/) {
		if ($content =~ /^(\d+)\s+(.*)$/) {
			$prio = $1;
			$content = $2;
		} else {
			die "bad format of rdata for $type";
		}
	}

	return ($fqdn, $type, $content, $ttl, $prio, $auth, $ordername);
}

sub add_zone {
	my $self = shift;
	my $zone = shift;
	my $records = shift;
	my $zone_type = shift;
	my $presigned = shift;
	my $nsec_type = shift;
	my $zone_status = shift;

	die "bad indata to add_zone" unless defined($zone) && ref($zone) eq "HASH" && defined($records) && ref($records) eq "ARRAY";

	$zone_type = 'NATIVE' unless defined($zone_type) && $zone_type eq 'MASTER';
	$nsec_type = 'NSEC3NARROW' unless defined($nsec_type) && $nsec_type =~ /^NSEC3?$/i;

	eval {
		my $name = $self->dbi->quote($zone->{"name"});

		if ($zone_type eq 'MASTER' && defined($presigned) && $presigned) {
			my $num_row = $self->dbi->selectrow_arrayref("SELECT COUNT(*) FROM domains WHERE type = 'MASTER' AND name = $name");
			die "error checking if presigned MASTER domain is already added" unless defined($num_row) && ref($num_row) eq "ARRAY" && scalar(@$num_row) == 1;
			return if $num_row->[0] == 1;
		}

		my $query = "SELECT id, type FROM domains WHERE name = $name";
		my $domain = $self->dbi->selectrow_arrayref($query);
		my $domain_id = defined($domain) && ref($domain) eq "ARRAY" && scalar(@$domain) == 2 ? $domain->[0] : -1;
		my $domain_type = defined($domain) && ref($domain) eq "ARRAY" && scalar(@$domain) == 2 ? $domain->[1] : undef;
		my $domain_exists = $domain_id != -1 ? 1 : 0;

		if ($domain_id == -1) {
			$query = "INSERT INTO domains (name, type) VALUES ($name, '$zone_type')";
			$self->dbi->do($query) || die "error inserting domain row: $DBI::errstr";
			$domain_id = $self->dbi(1)->last_insert_id(undef, undef, "domains", undef) || die "error retrieving last_insert_id";
		} elsif ($domain_id != -1 && $zone_type ne $domain_type) {
			$query = "UPDATE domains SET type = '$zone_type' WHERE id = $domain_id";
			$self->dbi->do($query) || die "error updating zone type: $DBI::errstr";
		}

		my @records_to_insert = ();

		if ($domain_exists) {
			my @db_ids_to_delete = ();

			my $existing_row_hash = {};
			my $rows = $self->dbi->selectall_arrayref("SELECT id, name, type, content, ttl, prio, auth, ordername FROM records WHERE domain_id = $domain_id");
			EXISTING_ROW: foreach my $row (@$rows) {
				next EXISTING_ROW unless defined($row);

				my @parsed_row = ($self->dbi->quote($row->[1]), $row->[2], $row->[3], $row->[4], defined($row->[5]) ? $row->[5] : "NULL", $row->[6], $self->dbi->quote($row->[7]));
				my $row_key = join "#", @parsed_row;
				$existing_row_hash->{$row_key} = $row->[0];
			}

			my $updated_record_hash = {};
			RECORD: foreach my $record (@$records) {
				next RECORD unless defined($record);

				my @parsed_row = $self->parse_record($record, $nsec_type, $zone, $name);
				my $row_key = join "#", @parsed_row;
				$updated_record_hash->{$row_key} = 1;

				if (!defined($existing_row_hash->{$row_key})) {
					push(@records_to_insert, $record);
				}
			}

			ROW: foreach my $existing_row_key (keys %$existing_row_hash) {
				if (!defined($updated_record_hash->{$existing_row_key})) {
					push(@db_ids_to_delete, $existing_row_hash->{$existing_row_key});
				}
			}

			if (scalar(@db_ids_to_delete) > 0) {
				$query = "DELETE FROM records WHERE id IN (" . join(",", @db_ids_to_delete) . ")";
				$self->dbi->do($query) || die "error when removing non existing records in zone: $DBI::errstr";
			}
		} else {
			@records_to_insert = @$records;
		}

		my $num_records = scalar(@records_to_insert);
		my $weed_dupes = {};

		for (my $batch = 0; $batch * 1000 < $num_records; $batch++) {
			$query = "INSERT INTO records (domain_id, name, type, content, ttl, prio, auth, ordername) VALUES ";

			my $first_in_batch = 1;

			RECORD: for (my $idx = 0; $idx < 1000 && $batch * 1000 + $idx < $num_records; $idx++) {
				my $record = $records_to_insert[$batch * 1000 + $idx];
				my ($fqdn, $type, $content, $ttl, $prio, $auth, $ordername) = $self->parse_record($record, $nsec_type, $zone, $name);
				my $label = $record->{"label"};

				my $dupe_key = "$label/$type/$content";
				next RECORD if exists($weed_dupes->{$dupe_key});
				$weed_dupes->{$dupe_key} = 1;

				$query .= sprintf("%s(%d, %s, %s, %s, %d, %s, %d, %s)", ($first_in_batch ? '' : ','), $domain_id, $fqdn, $self->dbi->quote($type), $self->dbi->quote($content), $ttl, $prio, $auth, $ordername);
				$first_in_batch = 0;
			}

			if($first_in_batch == 0)
			{
				$self->dbi->do($query) || die "error inserting record batch $batch, query=$query: $DBI::errstr";
			}

			my $disable_records = 0;
			if (defined($zone_status) && $zone_status eq 'suspended') {
				$disable_records = 1;
			}

			$query = "UPDATE records SET disabled = $disable_records WHERE domain_id = $domain_id AND type NOT IN ('NS', 'SOA')";
			$self->dbi->do($query) || die "error updating record disabled property, query=$query: $DBI::errstr";
		}

		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub remove_zone {
	my $self = shift;
	my $zone = shift;

	eval {
		my $name = $self->dbi->quote($zone->{"name"});
		$self->dbi->do("DELETE domains, records FROM domains INNER JOIN records ON domains.id = records.domain_id WHERE domains.name = $name") || die "error removing zone: $DBI::errstr";
		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub set_dnssec_metadata {
	my $self = shift;
	my $presigned = shift;
	my $also_notify = shift;
	my $nsec_type = shift;

	$presigned = 0 if defined($presigned) && $presigned != 1;
	$also_notify = '' unless defined($also_notify) && $also_notify =~ /^[\d.]+$/;
	$nsec_type = 'NSEC3NARROW' unless defined($nsec_type) && $nsec_type =~ /^NSEC3?$/i;

	my $query = "SELECT COUNT(*), COUNT(IF(kind = 'PRESIGNED', 1, NULL)), COUNT(IF(kind LIKE 'NSEC%', 1, NULL)), COUNT(IF(kind = 'ALSO-NOTIFY' AND content = '$also_notify', 1, NULL)), COUNT(IF(kind = 'SOA-EDIT', 1, NULL)) FROM global_domainmetadata";
	my $num_metadata = $self->dbi->selectrow_arrayref($query);
        die "error checking status of global metadata, query was $query" unless defined($num_metadata) && ref($num_metadata) eq "ARRAY" && scalar(@$num_metadata) == 5;

	my $db_is_presigned = (($num_metadata->[0] + ($also_notify ne '' ? 1 : 0) == $num_metadata->[1] + $num_metadata->[3]) && $num_metadata->[1] == 1);
	my $db_correct_nsec = 	($nsec_type eq 'NSEC3NARROW' && $num_metadata->[0] == 3 && $num_metadata->[2] == 2 && $num_metadata->[4] == 1) ||
				($nsec_type eq 'NSEC3' && $num_metadata->[0] == 2 && $num_metadata->[2] == 1 && $num_metadata->[4] == 1) ||
				($nsec_type eq 'NSEC' && $num_metadata->[0] == 1 && $num_metadata->[4] == 1);
	my $db_correct_notify = ($num_metadata->[3] == ($also_notify ne '' ? 1 : 0) && $num_metadata->[0] == 1);

	eval {
		if (defined($presigned) && $presigned && !$db_is_presigned) {
			$self->dbi->do("DELETE FROM global_domainmetadata");
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('PRESIGNED', '1')");
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('ALSO-NOTIFY', '$also_notify')") unless $also_notify eq '';
			$self->dbi->commit();
		} elsif (defined($presigned) && !$presigned && !$db_correct_nsec) {
			$self->dbi->do("DELETE FROM global_domainmetadata");
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('SOA-EDIT', 'INCEPTION-EPOCH')");
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('NSEC3PARAM', '1 1 " . $self->nsec3_iterations . " " . $self->nsec3_salt_pres . "')") if $nsec_type ne 'NSEC';
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('NSEC3NARROW', '1')") if $nsec_type eq 'NSEC3NARROW';
			$self->dbi->commit();
		} elsif (!defined($presigned) && !$db_correct_notify) {
			$self->dbi->do("DELETE FROM global_domainmetadata");
			$self->dbi->do("INSERT INTO global_domainmetadata (kind, content) VALUES ('ALSO-NOTIFY', '$also_notify')") unless $also_notify eq '';
		}
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub sync_keyset {
	my $self = shift;
	my $keyset = shift;

	my $keys_in_db = $self->dbi->selectall_arrayref("SELECT * FROM global_cryptokeys", { Slice => {} });
        die "error fetching crypto keys" unless defined($keys_in_db) && ref($keys_in_db) eq "ARRAY" && !$DBI::err;

	eval {
		my $changed = 0;

		CHECK_KEYS_TO_ADD: foreach my $key (@$keyset) {
			my $keydata = $key->{"keydata"};
			my $id = $key->{"id"};
			die "key from atomia dns has bad format" unless $keydata =~ /^Private-key-format/ && $id =~ /^\d+$/;

			foreach my $dbkey (@$keys_in_db) {
				if ($dbkey->{"content"} eq $keydata) {
					next CHECK_KEYS_TO_ADD;
				}
			}

			my $flags = $key->{"keytype"} eq "KSK" ? 257 : 256;
			my $active = $key->{"activated"} == 1 ? 1 : 0;
			$keydata = $self->dbi->quote($keydata);

			$self->dbi->do("INSERT INTO global_cryptokeys (id, flags, active, content) VALUES ($id, $flags, $active, $keydata)") || die "error inserting key into database: $DBI::errstr";
			$changed = 1;
		}

		CHECK_KEYS_TO_REMOVE: foreach my $key (@$keys_in_db) {
			my $keydata = $key->{"content"};
			my $id = $key->{"id"};
			die "key from database has bad format" unless $keydata =~ /^Private-key-format/ && $id =~ /^\d+$/;

			foreach my $soapkey (@$keyset) {
				if ($soapkey->{"keydata"} eq $keydata) {
					next CHECK_KEYS_TO_REMOVE;
				}
			}

			$self->dbi->do("DELETE FROM global_cryptokeys WHERE id = $id") || die "error removing key from database: $DBI::errstr";
			$changed = 1;
		}

		$self->dbi->commit() if $changed;
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub add_slave_zone {
	my $self = shift;
	my $zone = shift;
	my $options = shift;

	die "bad indata to add_zone" unless defined($zone) && ref($zone) eq "" && $zone =~ /^[a-z0-9.-]+$/ && defined($options) && ref($options) eq "HASH";
	die "invalid master" unless defined($options->{"master"}) && length($options->{"master"}) > 0;

	eval {
		my $name = $self->dbi->quote($zone);
		my $master = $self->dbi->quote($options->{"master"});
		my $tsig = $options->{"tsig_secret"};
		$tsig = undef if defined($tsig) && $tsig eq '';
		$tsig = $self->dbi->quote($tsig) if defined($tsig);

		my $tsig_name = $options->{"tsig_name"};
		$tsig_name = undef if defined($tsig_name) && $tsig_name eq '';
		$tsig_name = $self->dbi->quote($tsig_name) if defined($tsig_name);
		$tsig_name = "NULL" unless defined($tsig_name);

		$self->dbi->do("DELETE domains, records FROM domains LEFT JOIN records ON domains.id = records.domain_id WHERE domains.name = $name") || die "error removing previous version of zone in add_zone: $DBI::errstr";

		my $query = "INSERT INTO domains (name, type, master) VALUES ($name, 'SLAVE', $master)";

		$self->dbi->do($query) || die "error inserting domain row: $DBI::errstr";

		if (defined($tsig)) {
			my $domain_id = $self->dbi(1)->last_insert_id(undef, undef, "domains", undef) || die "error retrieving last_insert_id";
			$query = "INSERT INTO outbound_tsig_keys (domain_id, secret, name) VALUES ($domain_id, $tsig, $tsig_name)";
			$self->dbi->do($query) || die "error inserting tsig row using $query: $DBI::errstr";
		}

		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub remove_slave_zone {
	my $self = shift;
	my $zonename = shift;

	eval {
		my $name = $self->dbi->quote($zonename);
		$self->dbi->do("DELETE domains, records, k FROM domains LEFT JOIN records ON domains.id = records.domain_id LEFT JOIN outbound_tsig_keys k ON k.domain_id = domains.id WHERE domains.name = $name AND domains.type = 'SLAVE'") || die "error removing zone: $DBI::errstr";
		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub add_tsig_key {
	my $self = shift;
	my $tsig_key_name = shift;
	my $tsig_key_data = shift;

	die "bad input data to add tsig key" unless defined($tsig_key_name) && ref($tsig_key_name) eq "" && $tsig_key_name =~ /^[a-zA-Z0-9_-]*$/ && defined($tsig_key_data) && ref($tsig_key_data) eq "HASH";
	die "tsig secret missing" unless defined($tsig_key_data->{"secret"}) && length($tsig_key_data->{"secret"}) > 0;
	die "algorithm missing" unless defined($tsig_key_data->{"algorithm"}) && length($tsig_key_data->{"algorithm"}) > 0;

	eval {
		my $name = $self->dbi->quote($tsig_key_name);
		my $secret = $self->dbi->quote($tsig_key_data->{"secret"});
		my $algorithm = $self->dbi->quote($tsig_key_data->{"algorithm"});

		$self->dbi->do("DELETE FROM tsigkeys WHERE name = $name") || die "error removing previous tsigkey with the same name in add_tsig_key: $DBI::errstr";

		my $query = "INSERT INTO tsigkeys (name, algorithm, secret) VALUES ($name, $algorithm, $secret)";

		$self->dbi->do($query) || die "error inserting row: $DBI::errstr";

		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error rolling due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub remove_tsig_key {
	my $self = shift;
	my $tsig_key_name = shift;

	eval {
		my $name = $self->dbi->quote($tsig_key_name);
		$self->dbi->do("DELETE FROM tsigkeys WHERE name = $name") || die "error removing tsigkey: $DBI::errstr";
		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error while rolling back due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub assign_tsig_key {
	my $self = shift;
	my $domain_name = shift;
	my $domainmetadata = shift;

	die "bad input data to assign tsig key" unless defined($domain_name) && ref($domain_name) eq "" && defined($domainmetadata) && ref($domainmetadata) eq "HASH";
	die "tsig key name missing" unless defined($domainmetadata->{"tsigkey_name"}) && length($domainmetadata->{"tsigkey_name"}) > 0;
	die "tsig type missing" unless defined($domainmetadata->{"kind"}) && length($domainmetadata->{"kind"}) > 0;

	eval {
		$domain_name = $self->dbi->quote($domain_name);
		my $domain_id = $self->dbi->selectrow_arrayref("SELECT id FROM domains WHERE name = $domain_name");
		die "error fetching domain id from powerDNS domains table" unless defined($domain_id) && ref($domain_id) eq "ARRAY" && scalar(@$domain_id) == 1;
		$domain_id = $domain_id->[0];

		$domain_id = $self->dbi->quote($domain_id);
		my $tsigkey_name = $self->dbi->quote($domainmetadata->{"tsigkey_name"});
		my $tsigkey_kind = $self->dbi->quote($domainmetadata->{"kind"});

		my $query;
		my $domain_id_check = $self->dbi->selectrow_arrayref("SELECT id FROM domainmetadata WHERE domain_id = $domain_id AND kind = $tsigkey_kind");
		if (defined($domain_id_check) && ref($domain_id_check) eq "ARRAY") {
			$query = "UPDATE domainmetadata SET content = $tsigkey_name WHERE domain_id = $domain_id AND kind = $tsigkey_kind";
		}
		else {
			$query = "INSERT INTO domainmetadata (domain_id, kind, content) VALUES ($domain_id, $tsigkey_kind, $tsigkey_name)";
		}

		$self->dbi->do($query) || die "error inserting row: $DBI::errstr";

		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error while rolling back due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

sub unassign_tsig_key {
	my $self = shift;
	my $domain_name = shift;

	eval {
		$domain_name = $self->dbi->quote($domain_name);
		my $domain_id = $self->dbi->selectrow_arrayref("SELECT id FROM domains WHERE name = $domain_name");
		die "error fetching domain id from powerDNS domains table" unless defined($domain_id) && ref($domain_id) eq "ARRAY" && scalar(@$domain_id) == 1;
		$domain_id = $domain_id->[0];

		$domain_id = $self->dbi->quote($domain_id);
		$self->dbi->do("DELETE FROM domainmetadata WHERE domain_id = $domain_id AND kind IN ('TSIG-ALLOW-AXFR', 'AXFR-MASTER-TSIG')") || die "error unassigning tsigkey: $DBI::errstr";
		$self->dbi->commit();
	};

	if ($@) {
		my $exception = $@;
		$self->dbi->rollback() || die "error while rolling back due to exception $exception";
		
		die "caught exception $exception, rollback successfull";
	}
}

1;

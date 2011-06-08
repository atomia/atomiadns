#!/usr/bin/perl -w

package Atomia::DNS::PowerDNSDatabase;

use Moose;
use DBI;

has 'config' => (is => 'ro', isa => 'HashRef');
has 'conn' => (is => 'rw', isa => 'Object');

sub BUILD {
	my $self = shift;
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

        $self->validate_config($self->config);

        my $dbh = $self->conn;

        if (defined($dbh) && $dbh->ping) {
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

sub add_zone {
	my $self = shift;
	my $zone = shift;
	my $records = shift;

	die "bad indata to add_zone" unless defined($zone) && ref($zone) eq "HASH" && defined($records) && ref($records) eq "ARRAY";

	eval {
		my $name = $self->dbi->quote($zone->{"name"});

		$self->dbi->do("DELETE domains, records FROM domains INNER JOIN records ON domains.id = records.domain_id WHERE domains.name = $name") || die "error removing previous version of zone in add_zone: $DBI::errstr";

		my $query = "INSERT INTO domains (name, type) VALUES ($name, 'NATIVE')";

		$self->dbi->do($query) || die "error inserting domain row: $DBI::errstr";

		my $domain_id = $self->dbi->last_insert_id(undef, undef, "domains", undef) || die "error retrieving last_insert_id";

		my $num_records = scalar(@$records);

		for (my $batch = 0; $batch * 1000 < $num_records; $batch++) {
			$query = "INSERT INTO records (domain_id, name, type, content, ttl, prio, auth, ordername) VALUES ";

			for (my $idx = 0; $idx < 1000 && $batch * 1000 + $idx < $num_records; $idx++) {
				my $record = $records->[$batch * 1000 + $idx];
				my $content = $record->{"rdata"};
				my $type = $record->{"type"};
				my $ttl = $record->{"ttl"};
				my $label = $record->{"label"};


				my $prio = "NULL";
				my $fqdn = $label eq '@' ? $name : $self->dbi->quote($label . "." . $zone->{"name"});
				my $auth = ($type eq 'NS' && $label ne '@') ? 0 : 1;

				if ($type eq "SOA") {
					$content =~ s/%serial/$zone->{"changetime"}/g;
					$content =~ s/\. / /g;
					$content =~ s/^([^ ]* [^\.]*)\./$1\@/;
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


				$query .= sprintf("%s(%d, %s, %s, %s, %d, %s, %d, '')", ($idx == 0 ? '' : ','), $domain_id, $fqdn, $self->dbi->quote($type), $self->dbi->quote($content), $ttl, $prio, $auth);
			}

			$self->dbi->do($query) || die "error inserting record batch $batch, query=$query: $DBI::errstr";
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

1;

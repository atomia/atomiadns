#!/usr/bin/perl -w

use strict;
use warnings;

package UCPDNS::ServerHandler;

use Moose;
use Config::General;
use DBI;
use DBD::Pg qw(:pg_types);
use Data::Dumper;

has 'conn' => (is => 'rw', isa => 'Any', default => undef);
has 'config' => (is => 'rw', isa => 'Any', default => undef);
has 'configfile' => (is => 'ro', isa => 'Any', default => "/etc/ucpdns.conf");

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

	my $sth = undef;
	eval {
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

			} elsif ($signature->[$idx] eq "zone") {
				my $zone = $_[$idx];

				die("bad format of zone, should an array of structs, containing name and records") unless defined($zone) && ref($zone) eq "ARRAY";
				my $records = [];
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

			} else {
				# Default is varchar
				$sth->bind_param($idx + 1, $_[$idx], { pg_type => PG_VARCHAR });
			}
		}
	};

	if ($@) {
		die("error preparing statement for $method invocation: $@");
	}

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
			-> faultstring($@)
			-> faultdetail($detail);
}

sub mapExceptionToFault {
	my $self = shift;
	my $exception = shift;

# LogicalError.*
	if ($@ =~ /duplicate key value violates unique constraint/) {
		$self->generateException('LogicalError', 'Uniqueness', $@);
	} elsif ($@ =~ /zone .* not found/) {
		$self->generateException('LogicalError', 'ZoneNotFound', $@);
	} elsif ($@ =~ /record .* doesn.t exist in zone/) {
		$self->generateException('LogicalError', 'RecordNotFound', $@);
	} elsif ($@ =~ /both as source and destination/) {
		$self->generateException('LogicalError', 'SameSourceAndDestination', $@);
	} elsif ($@ =~ /moving .* cross.* are not supported/) {
		$self->generateException('LogicalError', 'CrossObjectMove', $@);
	} elsif ($@ =~ /and CNAME is not allowed with other data/) {
		$self->generateException('LogicalError', 'CNAMEAndOtherData', $@);
	} elsif ($@ =~ /is different from existing ttl for this label\/class\/type triplet/) {
		$self->generateException('LogicalError', 'DifferentTTLForSameLabelClassAndType', $@);
	} elsif ($@ =~ /zone needs to have/) {
		$self->generateException('LogicalError', 'ZoneRequiredRecords', $@);
	} elsif ($@ =~ /all labels have to have records/) {
		$self->generateException('LogicalError', 'EmptyLabel', $@);
# InvalidParametersError.*
	} elsif ($@ =~ /(refresh|retry|expire|minimum) value of .* is out of range/) {
		$self->generateException('InvalidParametersError', 'Soa' . $1, $@);
	} elsif ($@ =~ /is not an available type/) {
		$self->generateException('InvalidParametersError', 'BadType', $@);
	} elsif ($@ =~ /isn.t allowed rdata for (.*), synopsis/) {
		$self->generateException('InvalidParametersError', 'BadRdataFor' . $1, $@);
	} elsif ($@ =~ /bad changestatus .* when updating change with id/) {
		$self->generateException('InvalidParametersError', 'BadChangeStatus', $@);
	} elsif ($@ =~ /number of parameters doesn.t match the signature for/) {
		$self->generateException('InvalidParametersError', 'BadNumberOfParameters', $@);
	} elsif ($@ =~ /bad format of (\w+)\.(\w+)/) {
		$self->generateException('InvalidParametersError', 'Bad' . $1 . $2, $@);
	} elsif ($@ =~ /bad .*-array passed |.*\[\] can.t be empty/) {
		$self->generateException('InvalidParametersError', 'BadArray', $@);
# SystemError.*
	} elsif ($@ =~ /no .* returned from database|bad data returned from database|more than one .* returned for scalar|row without label returned|error polling database for changes/) {
		$self->generateException('SystemError', 'DatabaseBadResult', $@);
	} elsif ($@ =~ /error connecting to /) {
		$self->generateException('SystemError', 'DatabaseConnection', $@);
	} elsif ($@ =~ /error preparing statement for|error in dbi->prepare/) {
		$self->generateException('SystemError', 'PreparingStatement', $@);
	} else {
		$self->generateException('InternalError', 'UnknownException', $@);
	}
}

1;

#!/usr/bin/perl -w

use strict;
use warnings;

use SOAP::Lite;
use Data::Dumper;

my $soap = SOAP::Lite
	->  uri('urn:Atomia::DNS::Server')
	->  proxy('http://localhost/atomiadns')
	->  on_fault(sub {
			my($soap, $res) = @_;
			die "got fault of type " . (ref $res ? $res->faultcode : "transport") . ": " . (ref $res ? $res-> faultstring : $soap-> transport->status) . "\n";
		});

my $res = $soap->GetUpdatesDisabled();
die Dumper($res->result) unless defined($res) && defined($res->result);

$res = $soap->GetChangedZones($ARGV[0]);
die Dumper($res->result) unless defined($res) && defined($res->result);

$res = $soap->GetChangedSlaveZones($ARGV[0]);
die Dumper($res->result) unless defined($res) && defined($res->result);

$res = $soap->GetAllowedZoneTransfer();
die Dumper($res->result) unless defined($res) && defined($res->result);

#$res = $soap->RestoreZoneBinary($ARGV[0], 'default', $res->result);
#die Dumper($res->result) unless defined($res) && defined($res->result) && ref($res->result) eq "" && $res->result eq "ok";

print "simulated nameserver sync for " . $ARGV[0] . " succesfully.\n";
exit 0;

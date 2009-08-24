#!/usr/bin/perl -w

use strict;
use warnings;

use SOAP::Lite;
use Data::Dumper;

my $soap = SOAP::Lite
	-> service('http://s272.pingdom.com/wsdl-atomiadns.wsdl')
	-> on_fault(sub {
			my($soap, $res) = @_;
			die "got fault of type " . (ref $res ? $res->faultcode : "transport error") . ": " . (ref $res ? $res-> faultstring : $soap-> transport->status) . "\n";
		});

my $res;
$res = $soap->AddZone('sigint5.se', 3600, 'ns1.loopia.se.', 'registry2.loopia.se.', 10800, 3600, 604800, 86400, [ 'ns3.loopia.se', 'ns419.loopia.se' ]);

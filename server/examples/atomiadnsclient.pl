#!/usr/bin/perl -w

use strict;
use warnings;

use SOAP::Lite;
use Data::Dumper;

my $soap = SOAP::Lite
	->  uri('urn:Atomia::DNS::Server')
	->  proxy('http://s272.pingdom.com/atomiadns')
	->  on_fault(sub {
			my($soap, $res) = @_;
			die "got fault of type " . (ref $res ? $res->faultcode : "transport") . ": " . (ref $res ? $res-> faultstring : $soap-> transport->status) . "\n";
		});

my $res;
#$res = $soap->AddZone('sigint4.se', 3600, 'ns1.loopia.se.', 'registry2.loopia.se.', 10800, 3600, 604800, 86400, [ 'ns3.loopia.se', 'ns419.loopia.se' ]);
#$res = $soap->DeleteZone('sigint5aaaaaa.se');
#$res = $soap->AddZone('sigint5.se', 3600, 'ns1.loopia.se.', 'registry2.loopia.se.', 10800, 3600, 604800, 86400, [ 'ns3.loopia.se', 'ns419.loopia.se' ]);
#$res = $soap->AddDnsRecords('sigint4.se', [ SOAP::Data->new(name => 'resourcerecord', value => { label => 'bar', class => 'IN', ttl => 3600, type => 'MX', rdata => '10 kaka456.sigint.se.' }) ]);
#$res = $soap->EditDnsRecords('sigint.se', [ SOAP::Data->new(name => 'resourcerecord', value => { id => 5, label => 'kaka', class => 'IN', ttl => 3600, type => 'A', rdata => '127.0.0.1' }) ]);
#$res = $soap->GetDnsRecords('sigint.se', 'kaka123');
#$res = $soap->DeleteDnsRecords('sigint.se', $res->result);
#$res = $soap->GetLabels('sigint.se');
#$res = $soap->SetDnsRecords('sigint.se', [ SOAP::Data->new(name => 'resourcerecord', value => { label => 'www', class => 'IN', ttl => 3600, type => 'A', rdata => '127.0.0.142' }) ]);
#$res = $soap->SetDnsRecordsBulk([ 'sigint.se', 'sigint2.se' ], [ SOAP::Data->new(name => 'resourcerecord', value => { label => 'www', class => 'IN', ttl => 3600, type => 'A', rdata => '127.0.0.142' }) ]);
#$res = $soap->CopyDnsZoneBulk('sigint.se', [ 'sigint3.se', 'sigint2.se' ]);
#$res = $soap->CopyDnsLabelBulk('sigint.se', 'www', [ SOAP::Data->new(name => 'hostname', value => { zone => 'sigint3.se', label => 'www' }),
#							SOAP::Data->new(name => 'hostname', value => { zone => 'sigint2.se', label => 'www' }) ]);
#$res = $soap->GetZone('sigint.se');
#$res = $soap->DeleteZone('sigint2.se');
#$res = $soap->AddNameserver('testnameserver.se');
#$res = $soap->MarkUpdated(1, 'OK');
#$res = $soap->MarkUpdated(2, 'OK');
#$res = $soap->GetChangedZones('testnameserver.se');
#$res = $soap->GetAllZones();

my $sigint = [
          {
            'records' => [
                           {
                             'ttl' => '3600',
                             'label' => '@',
                             'class' => 'IN',
                             'id' => '3837',
                             'type' => 'MX',
                             'rdata' => '10 mailin.telia.com.'
                           },
                           {
                             'ttl' => '3600',
                             'label' => '@',
                             'class' => 'IN',
                             'id' => '3819',
                             'type' => 'NS',
                             'rdata' => 'dnshosting1-sn0.ref.utv.skanova.net.'
                           },
                           {
                             'ttl' => '3600',
                             'label' => '@',
                             'class' => 'IN',
                             'id' => '3818',
                             'type' => 'SOA',
                             'rdata' => 'dnshosting1-sn0.ref.utv.skanova.net. registry.telia.com. %serial 1200 180 1209600 1209600'
                           }
                         ],
            'name' => '@'
          },
          {
            'records' => [
                           {
                             'ttl' => '3600',
                             'label' => 'ns1',
                             'class' => 'IN',
                             'id' => '3820',
                             'type' => 'NS',
                             'rdata' => '1.1.1.1.'
                           }
                         ],
            'name' => 'ns1'
          },
          {
            'records' => [
                           {
                             'ttl' => '3600',
                             'label' => 'wwwww',
                             'class' => 'IN',
                             'id' => '3821',
                             'type' => 'A',
                             'rdata' => '2.2.2.2'
                           }
                         ],
            'name' => 'wwwww'
          }
        ];


$res = $soap->RestoreZone('nissegurra.se', "secondgroup", $sigint);
print Dumper($res->result);

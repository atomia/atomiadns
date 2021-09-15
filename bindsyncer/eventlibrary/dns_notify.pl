#!/usr/bin/perl

use Net::DNS;

die "usage: $0 domain ip" unless scalar(@ARGV) >= 2;

my $domain = $ARGV[0];
my $ip = $ARGV[1];

my $packet = new Net::DNS::Packet($domain, "SOA", "IN");
die "error creating NOTIFY packet" unless defined($packet);
($packet->header)->opcode("NS_NOTIFY_OP");
($packet->header)->rd(0);
($packet->header)->aa(1);

my $resolver = new Net::DNS::Resolver || die "error instantiating resolver";
$resolver->nameservers($ip);

my $reply = $resolver->send($packet);
die "got bad response for NOTIFY" unless defined($reply);

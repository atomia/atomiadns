#!/usr/bin/perl -w

use strict;
use warnings;

package UCPDNS::Server;

use UCPDNS::ServerHandler;
use Moose;

my $signatures = {
	"AddZone" => "void string int string string int int int int array",
	"DeleteZone" => "void string",
	"EditZone" => "void string int string string int int int int array",
	"AddDnsRecords" => "void string array[resourcerecord]",
	"EditDnsRecords" => "void string array[resourcerecord]",
	"SetDnsRecords" => "void string array[resourcerecord]",
	"DeleteDnsRecords" => "void string array[resourcerecord]",
	"GetDnsRecords" => "array[resourcerecord] string string",
	"GetLabels" => "array[string] string",
	"GetZone" => "zone string",
	"RestoreZone" => "void string zone",
	"SetDnsRecordsBulk" => "void array array[resourcerecord]",
	"CopyDnsZoneBulk" => "void string array",
	"CopyDnsLabelBulk" => "void string string array[hostname]",
	"DeleteDnsRecordsBulk" => "void array array[resourcerecord]",
	"AddNameserver" => "void string",
	"DeleteNameserver" => "void string",
	"GetChangedZones" => "changes string",
	"MarkUpdated" => "void int string string",
	"GetAllZones" => "zonestruct",
	"ReloadAllZones" => "void",
	"GetUpdatesDisabled" => "int",
	"SetUpdatesDisabled" => "void int",
};

our $instance = UCPDNS::ServerHandler->new;

foreach my $method (keys %{$signatures}) {
	my $textsignature = $signatures->{$method};
	my @signature = split(" ", $textsignature);

	my $return_type = shift @signature;	
	__PACKAGE__->meta->add_method($method, sub {
		my $self = shift;

		my $retval = eval {
			$UCPDNS::Server::instance->matchSignature($method, \@signature, @_);

			if ($return_type eq "void") {
				$UCPDNS::Server::instance->handleVoid($method, \@signature, @_);
			} elsif ($return_type eq "array[resourcerecord]") {
				$UCPDNS::Server::instance->handleRecordArray($method, \@signature, @_);
			} elsif ($return_type eq "array[string]") {
				$UCPDNS::Server::instance->handleStringArray($method, \@signature, @_);
			} elsif ($return_type eq "zone") {
				$UCPDNS::Server::instance->handleZone($method, \@signature, @_);
			} elsif ($return_type eq "changes") {
				$UCPDNS::Server::instance->handleChanges($method, \@signature, @_);
			} elsif ($return_type eq "zonestruct") {
				$UCPDNS::Server::instance->handleZoneStruct($method, \@signature, @_);
			} elsif ($return_type eq "int") {
				$UCPDNS::Server::instance->handleInt($method, \@signature, @_);
			} else {
				die("unknown return-type in signature: $return_type");
			}
		};

		if ($@) {
			$UCPDNS::Server::instance->mapExceptionToFault($@);
		} else {
			return $retval;
		}
	});
}

1;

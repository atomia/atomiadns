#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::Server;

use Atomia::DNS::ServerHandler;
use Moose;

my $signatures = {
	"AddZone" => "void string int string string int int int int array string",
	"DeleteZone" => "void string",
	"EditZone" => "void string int string string int int int int array string",
	"AddDnsRecords" => "array[int] string array[resourcerecord]",
	"EditDnsRecords" => "void string array[resourcerecord]",
	"SetDnsRecords" => "void string array[resourcerecord]",
	"DeleteDnsRecords" => "void string array[resourcerecord]",
	"GetDnsRecords" => "array[resourcerecord] string string",
	"GetLabels" => "array[string] string",
	"GetZone" => "zone string",
	"GetZoneBinary" => "binaryzone string",
	"RestoreZone" => "void string string zone",
	"RestoreZoneBinary" => "void string string binaryzone",
	"RestoreZoneBulk" => "void array[bulkzones] string array[binaryzone]",
	"SetDnsRecordsBulk" => "void array array[resourcerecord]",
	"CopyDnsZoneBulk" => "void string array",
	"CopyDnsLabelBulk" => "void string string array[hostname]",
	"DeleteDnsRecordsBulk" => "void array array[resourcerecord]",
	"AddNameserver" => "void string string",
	"DeleteNameserver" => "void string",
	"GetNameserver" => "string string",
	"GetChangedZones" => "changes string",
	"MarkUpdated" => "void int string string",
	"MarkAllUpdatedExcept" => "void string int",
	"GetAllZones" => "zonestruct",
	"ReloadAllZones" => "void",
	"GetUpdatesDisabled" => "int",
	"SetUpdatesDisabled" => "void int",
	"GetNameserverGroup" => "string string",
	"SetNameserverGroup" => "void string string",
	"AddNameserverGroup" => "void string",
	"DeleteNameserverGroup" => "void string",
	"AddSlaveZone" => "void string string string",
	"DeleteSlaveZone" => "void string",
	"GetChangedSlaveZones" => "changes string",
	"MarkSlaveZoneUpdated" => "void int string string",
	"GetSlaveZone" => "slavezone string",
	"ReloadAllSlaveZones" => "void",
	"AllowZoneTransfer" => "void string string",
	"GetAllowedZoneTransfer" => "allowedtransfer",
	"DeleteAllowedZoneTransfer" => "void string string",
};

our $instance = Atomia::DNS::ServerHandler->new;

foreach my $method (keys %{$signatures}) {
	my $textsignature = $signatures->{$method};
	my @signature = split(" ", $textsignature);

	my $return_type = shift @signature;	
	__PACKAGE__->meta->add_method($method, sub {
		my $self = shift;

		my $retval = eval {
			$Atomia::DNS::Server::instance->matchSignature($method, \@signature, @_);

			if ($return_type eq "void") {
				$Atomia::DNS::Server::instance->handleVoid($method, \@signature, @_);
			} elsif ($return_type eq "array[resourcerecord]") {
				$Atomia::DNS::Server::instance->handleRecordArray($method, \@signature, @_);
			} elsif ($return_type eq "array[string]") {
				$Atomia::DNS::Server::instance->handleStringArray($method, \@signature, @_);
			} elsif ($return_type eq "string") {
				$Atomia::DNS::Server::instance->handleString($method, \@signature, @_);
			} elsif ($return_type eq "binaryzone") {
				$Atomia::DNS::Server::instance->handleBinaryZone($method, \@signature, @_);
			} elsif ($return_type eq "array[int]") {
				$Atomia::DNS::Server::instance->handleIntArray($method, \@signature, @_);
			} elsif ($return_type eq "zone") {
				$Atomia::DNS::Server::instance->handleZone($method, \@signature, @_);
			} elsif ($return_type eq "slavezone") {
				$Atomia::DNS::Server::instance->handleSlaveZone($method, \@signature, @_);
			} elsif ($return_type eq "changes") {
				$Atomia::DNS::Server::instance->handleChanges($method, \@signature, @_);
			} elsif ($return_type eq "zonestruct") {
				$Atomia::DNS::Server::instance->handleZoneStruct($method, \@signature, @_);
			} elsif ($return_type eq "int") {
				$Atomia::DNS::Server::instance->handleInt($method, \@signature, @_);
			} elsif ($return_type eq "allowedtransfer") {
				$Atomia::DNS::Server::instance->handleAllowedTransfer($method, \@signature, @_);
			} else {
				die("unknown return-type in signature: $return_type");
			}
		};

		if ($@) {
			$Atomia::DNS::Server::instance->mapExceptionToFault($@);
		} else {
			return $retval;
		}
	});
}

1;

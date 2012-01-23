#!/usr/bin/perl -w

use strict;
use warnings;

package Atomia::DNS::Server;

BEGIN {
	use Atomia::DNS::Signatures;
	use Atomia::DNS::ServerHandler;
	use Moose;

	my $signatures = $Atomia::DNS::Signatures::signatures;

	our $instance = Atomia::DNS::ServerHandler->new;
	
	foreach my $method (keys %{$signatures}) {
		my $textsignature = $signatures->{$method};
		my @signature = split(" ", $textsignature);
		my $signature_ref = \@signature;
	
		__PACKAGE__->meta->add_method($method, sub {
			my $self = shift;
			my $request = Apache2::RequestUtil->request();
	
			my $retval = eval {
				my $authenticated_account = $Atomia::DNS::Server::instance->authenticateRequest($request);
				$Atomia::DNS::Server::instance->handleOperation($authenticated_account, $method, $signature_ref, @_);
			};
	
			if ($@) {
				my $exception = $@;
				$Atomia::DNS::Server::instance->mapExceptionToFault($exception);
			} else {
				return $retval;
			}
		});
	}
};

1;

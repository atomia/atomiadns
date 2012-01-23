use strict;
use warnings;

package Atomia::DNS::JSONServer;

use Atomia::DNS::ServerHandler;
use Atomia::DNS::Signatures;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK HTTP_BAD_REQUEST HTTP_UNAUTHORIZED HTTP_FORBIDDEN);
use APR::Table;
use CGI qw(self_url);
use Data::Dumper;
use JSON;
use SOAP::Lite;

BEGIN {
	our $instance = Atomia::DNS::ServerHandler->new;
	our $json = JSON->new->allow_nonref(1);
};

sub handler {
	my $request = shift;

	$request->content_type('application/json');

	my $retval = eval {
		my $path = $request->uri();
		my $operation_offset = rindex($path , '/');
		if ($operation_offset < 0) {
			die "protocol violation: request path doesn't contain /";
		}

		my $encoder = ($path =~ /\/pretty\//) ? $Atomia::DNS::JSONServer::json->pretty(1) : $Atomia::DNS::JSONServer::json->pretty(0);

		my $operation = substr($path, $operation_offset + 1);
		if ($operation eq '') {
			my $base_url = self_url();

			my $index_response = {};
			foreach my $name (keys %$Atomia::DNS::Signatures::signatures) {
				$index_response->{$name} = { href => "$base_url$name", signature => $Atomia::DNS::Signatures::signatures->{$name} };
			}

			return $encoder->encode($index_response);
		}

		my $content = undef;
		my $len = $request->headers_in->{'Content-Length'};
		if (defined($len)) {
			my $max = $Atomia::DNS::JSONServer::instance->config->{"max_content_length"} || (10 * 1024 * 1024);
			die "request body is larger than the configured max_content_length value $max" if $len > $max;

			$request->read($content, $len);
		}

		my $authenticated_account = $Atomia::DNS::JSONServer::instance->authenticateRequest($request);

		unless (defined($content) && $content =~ /^\s*\[.*\]\s*$/s) {
			$content = $request->args();

			unless (defined($content) && $content =~ /^\s*\[.*\]\s*$/s) {
				# neither the request body nor the query string contains an JSON encoded array of the operation arguments, we'll treat it as []
				$content = "[]";
			}
		}

		my $json_args = $Atomia::DNS::JSONServer::json->decode($content);
		die "failed to deserialize the JSON-encoded argument array" unless defined($json_args) && ref($json_args) eq "ARRAY";

                my $textsignature = $Atomia::DNS::Signatures::signatures->{$operation};
		die "unsupported operation: $operation" unless defined($textsignature) && length($textsignature) > 0;
                my @signature = split(" ", $textsignature);

		my $ret = $Atomia::DNS::JSONServer::instance->handleOperation($authenticated_account, $operation, \@signature, @$json_args);
		die "unknown response from handleOperation($operation)" unless defined($ret) && ref($ret) && UNIVERSAL::isa($ret, 'SOAP::Data');

		return $encoder->encode(deserialize_soap_data($ret));
	};

	if ($@) {
		my $exception = $@;
		eval {
			$Atomia::DNS::JSONServer::instance->mapExceptionToFault($exception);
		};

		my $http_code = 400;
		my $mapped_exception = undef;
		if ($@) {
			$mapped_exception = $@;
			if (defined($mapped_exception) && ref($mapped_exception) && UNIVERSAL::isa($mapped_exception, 'SOAP::Fault')) {
				$http_code = 401 if $mapped_exception->faultcode() eq "AuthError.NotAuthenticated";
				$http_code = 403 if $mapped_exception->faultcode() eq "AuthError.NotAuthorized";
				$mapped_exception = { error_type => $mapped_exception->faultcode(), error_message => $mapped_exception->faultstring() };
			} else {
				$mapped_exception = undef;
			}
		}

		$mapped_exception = { error_type => "InternalError.InvalidErrorHandling", error_message => (ref($exception) ? 'unknown exception object thrown' : $exception) } unless defined($mapped_exception);

		my $output = undef;
		eval {
			$output = $Atomia::DNS::JSONServer::json->encode($mapped_exception);
		};

		$exception = $@;

		if (defined($output)) {
			$request->print(encode_json($mapped_exception));
		} else {
			$request->print("unserializable exception thrown");
		}

		$request->status(Apache2::Const::HTTP_BAD_REQUEST) if $http_code == 400;
		$request->status(Apache2::Const::HTTP_UNAUTHORIZED) if $http_code == 401;
		$request->status(Apache2::Const::HTTP_FORBIDDEN) if $http_code == 403;
	} else {
		$request->print($retval);
	}

	return Apache2::Const::OK;
}

sub deserialize_soap_data {
	my $soap_data = shift;

	my $xml = SOAP::Serializer->prefix('s')->uri('http://dummyhost/dummymethod')->envelope(response => "dummyResponse", $soap_data);
	die "error serializing SOAP::Data into XML" unless defined($xml);

	my $som = SOAP::Deserializer->deserialize($xml);
	die "error generating intermediate SOAP::SOM from response" unless defined($som) && defined($som->result);

	return $som->result;
}

1;

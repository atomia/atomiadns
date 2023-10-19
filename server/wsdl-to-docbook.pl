#!/usr/bin/perl -w

use warnings;
use strict;

my $wsdl_filename = "wsdl-atomiadns.wsdl";

my $type_mappings = {
	"xsd:string" => "string",
	"xsd:int" => "int",
	"xsd:long" => "bigint",
	"xsdAtomiaStringArray" => "string[]",
	"xsdAtomiaIntArray" => "int[]",
	"xsdAtomiaLongArray" => "bigint[]",
	"atomiaRecordArray" => "resourcerecord[]",
	"atomiaResourceRecord" => "resourcerecord",
	"atomiaZone" => "zone",
	"atomiaLabel" => "label",
	"atomiaHostnameArray" => "hostname[]",
	"atomiaHostname" => "hostname",
	"atomiaChanges" => "changes",
	"atomiaChangedZone" => "changedzone",
	"atomiaZoneStruct" => "zonestruct",
	"atomiaZones" => "zones",
	"atomiaSlaveZones" => "slavezones",
	"atomiaSlaveZoneItem" => "slavezone",
	"atomiaTransferAllowed" => "allowedtransfer",
	"atomiaAllowedTransfers" => "allowedtransfers",
	"atomiaBinaryZoneArray" => "binaryzones",
	"atomiaBinaryZone" => "binaryzone",
	"atomiaKeySet" => "keyset",
	"atomiaDSSet" => "ds_set",
	"atomiaExternalKeySet" => "external_keyset",
	"atomiaZSKInfo" => "zskinfo",
	"atomiaFindResponse" => "findresponse",
	"atomiaMetadata" => "zonemetadata",
	"atomiaMetadataArray" => "zonemetadata[]",
	"atomiaTSIGKeyAssignmentList" => "tsigkeyassignmentlist",
	"atomiaTSIGKeyAssignmentItem" => "tsigkeyassignmentitem",
};

use XML::XPath;
use XML::XPath::XMLParser;
    
my $xp = XML::XPath->new(filename => $wsdl_filename);
  
my $global_directory = "docbook_api_documentation"; 
mkdir($global_directory) unless -d $global_directory;
open OUTPUT_TYPE_INDEX, ">$global_directory/typeindex.xml";
open OUTPUT_TYPE_INCLUDES, ">$global_directory/typeincludes.xml";
open OUTPUT_METHOD_INDEX, ">$global_directory/methodindex.xml";
open OUTPUT_METHOD_INCLUDES, ">$global_directory/methodincludes.xml";

print OUTPUT_TYPE_INDEX qq(<?xml version="1.0"?>\n<itemizedlist>\n);
print OUTPUT_METHOD_INDEX qq(<?xml version="1.0"?>\n<itemizedlist>\n);
print OUTPUT_TYPE_INCLUDES qq(<?xml version="1.0"?>\n<section xml:id="api-datatypes">\n);
print OUTPUT_TYPE_INCLUDES qq(<title>Atomia DNS API Datatypes</title><para>Besides the standard SOAP Data types, the following types are returned by some methods:</para>\n);
print OUTPUT_TYPE_INCLUDES qq(<xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="typeindex.xml" />\n);

print OUTPUT_METHOD_INCLUDES qq(<?xml version="1.0"?>\n<section xml:id="api-methods">\n);
print OUTPUT_METHOD_INCLUDES qq(<title>Atomia DNS API Methods</title>\n);
print OUTPUT_METHOD_INCLUDES qq(<xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="methodindex.xml" />\n);

my $types = $xp->find('/definitions/types/xsd:schema/xsd:complexType');
foreach my $type (@$types) {
	my $typename = $type->getAttribute("name");

	my $documentation = $xp->find("xsd:annotation/xsd:documentation", $type);
	if (defined($documentation) && ref($documentation) eq "XML::XPath::NodeSet" && $documentation->size() == 1) {
		$documentation = $documentation->string_value();
		foreach my $mapping (keys %$type_mappings) {
			my $mapping_link = ($mapping =~ /^atomia/ ? link_to_type($type_mappings->{$mapping}) : $type_mappings->{$mapping});
			$documentation =~ s/$mapping(?![a-zA-Z])/$mapping_link/g;
		}

		my $mapped_name = $type_mappings->{$typename};
		print_type($mapped_name, $documentation, $global_directory);
		printf OUTPUT_TYPE_INDEX qq(<listitem><para><link linkend="datatype-%s">%s Datatype - Atomia DNS API</link></para></listitem>\n), $mapped_name, $mapped_name;
		printf OUTPUT_TYPE_INCLUDES qq(<xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="types/%s.xml" />\n), $mapped_name;
	}
}

print OUTPUT_TYPE_INDEX "</itemizedlist>\n";
close OUTPUT_TYPE_INDEX;
print OUTPUT_TYPE_INCLUDES "</section>\n";
close OUTPUT_TYPE_INCLUDES;

my $methods = $xp->find('/definitions/binding/operation');
    
foreach my $method ($methods->get_nodelist) {
	my $methodname = $method->getAttribute("name");
	die("bad wsdl, operation-tag in the bindings don't have a name attribute") unless defined($methodname);

	my $documentation = $xp->find("documentation", $method);
	if (defined($documentation)) {
		$documentation = $documentation->string_value();
	} else {
		$documentation = "";
	}

	my $returntype = $xp->find("/definitions/types/xsd:schema/xsd:element[\@name='${methodname}Response'");
	if (defined($returntype)) {
		my $returnnode = $returntype->get_node(1);
		$returntype = $xp->find("xsd:complexType/xsd:all/xsd:element", $returnnode);

		if ($returntype->size() == 1 && $returntype->get_node(1)->getAttribute("name") eq "status") {
			$returntype = "void";
		} elsif ($returntype->size() == 1 && defined($returntype->get_node(1)->getAttribute("type"))) {
			$returntype = convert_to_typename($returntype->get_node(1)->getAttribute("type"));
		} else {
			die("unknown return type for $methodname");
		}
	} else {
		die("return type not found for $methodname");
	}

	my $parameters = [];
	my $parameters_node = $xp->find("/definitions/types/xsd:schema/xsd:element[\@name='$methodname'");
	if (defined($parameters_node)) {
		$parameters_node = $parameters_node->get_node(1);
		my $parameters_nodes = $xp->find("xsd:complexType/xsd:all/xsd:element", $parameters_node);

		foreach my $param (@$parameters_nodes) {
			my $paramhash = {};
			$paramhash->{"name"} = $param->getAttribute("name");
			$paramhash->{"type"} = convert_to_typename($param->getAttribute("type"));

			my $description = $xp->find("xsd:annotation/xsd:documentation", $param);
			if (defined($description)) {
				$description = $description->string_value();
			} else {
				$description = "";
			}

			$paramhash->{"description"} = $description;

			push @$parameters, $paramhash;
		}
	} else {
		die("parameters not found for $methodname");
	}

	print_method($methodname, $documentation, $returntype, $parameters, $global_directory);
	printf OUTPUT_METHOD_INDEX qq(<listitem><para><link linkend="method-%s">%s Method - Atomia DNS API</link></para></listitem>\n), $methodname, $methodname;
	printf OUTPUT_METHOD_INCLUDES qq(<xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="methods/%s.xml" />\n), $methodname;
}

print OUTPUT_METHOD_INDEX "</itemizedlist>\n";
close OUTPUT_METHOD_INDEX;
print OUTPUT_METHOD_INCLUDES "</section>\n";
close OUTPUT_METHOD_INCLUDES;

sub convert_to_typename {
	my $type = shift;

	die("unknown type $type") unless defined($type_mappings->{$type});
	return $type =~ /^atomia/ ? link_to_type($type_mappings->{$type}) : $type_mappings->{$type};
}

sub link_to_type {
	my $type = shift;

	my ($basetype, $suffix);
	if ($type =~ /^(.*)\[\]$/) {
		$basetype = $1;
		$suffix = "[]";
	} else {
		$basetype = $type;
		$suffix = "";
	}

	return "[$basetype|$basetype Datatype - Atomia DNS API]$suffix";
}

sub print_method {
	my ($methodname, $documentation, $returntype, $parameters, $directory) = @_;

	mkdir($directory) unless -d $directory;
	mkdir("$directory/methods") unless -d "$directory/methods";
	open OUTPUT, ">$directory/methods/$methodname.xml";

	print OUTPUT "<section xml:id=\"method-$methodname\">\n";
	print OUTPUT "<title>$methodname Method - Atomia DNS API</title>\n";
	printf OUTPUT qq(<itemizedlist><listitem><para><link linkend="%s">Declaration syntax</link></para></listitem>), "method-declaration-$methodname";

	if (scalar(@$parameters) > 0) {
		printf OUTPUT qq(<listitem><para><link linkend="%s">Parameters</link></para></listitem>\n), "method-parameters-$methodname";
	}

	print OUTPUT "</itemizedlist><para>$documentation</para>\n";
	printf OUTPUT qq(<section xml:id="%s"><title>Declaration syntax</title><programlisting>\n), "method-declaration-$methodname";

	print OUTPUT "$returntype $methodname(" . (scalar(@$parameters) < 1 ? "" : "\n");

	for (my $idx = 0; $idx < scalar(@$parameters); $idx++) {
		my $param = $parameters->[$idx];
		printf OUTPUT ("\t%s %s%s\n", $param->{"type"}, $param->{"name"}, ($idx + 1 >= scalar(@$parameters) ? "" : ","));
	}

	print OUTPUT ")\n</programlisting></section>\n";

	if (scalar(@$parameters) > 0) {
		printf OUTPUT qq(<section xml:id="%s"><title>Parameters</title>\n), "method-parameters-$methodname";
		printf OUTPUT "<informaltable><colgroup /><thead><tr><td><para>Parameter</para></td><td><para>Type</para></td><td><para>Description</para></td></tr></thead><tbody>\n";
		foreach my $param (@$parameters) {
			printf OUTPUT ("<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n", $param->{"name"}, $param->{"type"}, $param->{"description"});
		}
		print OUTPUT "</tbody></informaltable></section>\n";
	}

	print OUTPUT "</section>\n";

	close OUTPUT;
}

sub print_type {
	my ($typename, $documentation, $directory) = @_;

	mkdir($directory) unless -d $directory;
	mkdir("$directory/types") unless -d "$directory/types";

	$documentation =~ s/\[(.*?)\|\1 Datatype - Atomia DNS API\]/<link linkend="datatype-$1">$1<\/link>/g;
	$documentation =~ s/\|\| Member \|\| Type \|\| Description \|\|/<informaltable><colgroup \/><thead><tr><td><para>Parameter<\/para><\/td><td><para>Type<\/para><\/td><td><para>Description<\/para><\/td><\/tr><\/thead><tbody>/g;
	$documentation =~ s/^\| /<tr><td>/gm;
	$documentation =~ s/ \|$/<\/td><\/tr>/gm;
	$documentation =~ s/ \| /<\/td><td>/g;
	$documentation =~ s/{excerpt:hidden=true}{excerpt}/<\/tbody><\/informaltable>\n/;

	open OUTPUT, ">$directory/types/$typename.xml";
	print OUTPUT "<section xml:id=\"datatype-$typename\">\n";
	print OUTPUT "<title>$typename Datatype - Atomia DNS API</title>\n";
	print OUTPUT "<para>$documentation</para></section>\n";
	close OUTPUT;
}

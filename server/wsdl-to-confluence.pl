#!/usr/bin/perl -w

use warnings;
use strict;

my $wsdl_filename = "wsdl-atomiadns.wsdl";

my $type_mappings = {
	"xsd:string" => "string",
	"xsd:int" => "int",
	"xsdAtomiaStringArray" => "string[]",
	"xsdAtomiaIntArray" => "int[]",
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
	"atomiaFindResponse" => "findresponse"
};

use XML::XPath;
use XML::XPath::XMLParser;
    
my $xp = XML::XPath->new(filename => $wsdl_filename);
   
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

		print_type($type_mappings->{$typename}, $documentation, "confluence_documentation");
	}
}

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

	print_method($methodname, $documentation, $returntype, $parameters, "confluence_documentation");
}

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
	mkdir("$directory/methods/$methodname Method - Atomia DNS API") unless -d "$directory/methods/$methodname Method - Atomia DNS API";
	open OUTPUT, ">$directory/methods/$methodname Method - Atomia DNS API/$methodname Method - Atomia DNS API.txt";

	print OUTPUT "{toc:maxLevel=3|type=flat|separator=pipe|includePages=true}\n\n";

	print OUTPUT "$documentation\n\n";

	print OUTPUT "h3.Declaration syntax\n{panel}\n";
	print OUTPUT "$returntype $methodname(" . (scalar(@$parameters) < 1 ? "" : "\n");

	for (my $idx = 0; $idx < scalar(@$parameters); $idx++) {
		my $param = $parameters->[$idx];
		printf OUTPUT ("\t%s %s%s\n", $param->{"type"}, $param->{"name"}, ($idx + 1 >= scalar(@$parameters) ? "" : ","));
	}

	print OUTPUT ")\n{panel}\n\n";

	if (scalar(@$parameters) > 0) {
		print OUTPUT "h3.Parameters\n\n";
		print OUTPUT "|| Parameter || Type || Description ||\n";
		foreach my $param (@$parameters) {
			printf OUTPUT ("|%s|%s|%s|\n", $param->{"name"}, $param->{"type"}, $param->{"description"});
		}
		print OUTPUT "\n";
	}

	print OUTPUT "{include:$methodname Method Example - Atomia DNS API}\n";

	close OUTPUT;
}

sub print_type {
	my ($typename, $documentation, $directory) = @_;

	mkdir($directory) unless -d $directory;
	mkdir("$directory/types") unless -d "$directory/types";
	mkdir("$directory/types/$typename Datatype - Atomia DNS API") unless -d "$directory/methods/$typename Datatype - Atomia DNS API";

	open OUTPUT, ">$directory/types/$typename Datatype - Atomia DNS API/$typename Datatype - Atomia DNS API.txt";
	print OUTPUT "$documentation";
	close OUTPUT;
}

#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ] || [ ! -f "$2" ]; then
	echo "usage: $0 method_regexp xsd"
	exit 1
fi

methodawk='BEGIN {
	methods["AddZone"] = "Add a zone to the Atomia DNS master database.";
	methods["DeleteZone"] = "Deletes a zone from the database.";
	methods["EditZone"] = "Edits a zone. This is only for completeness, and could be done by editing the SOA and NS-records directly as well.";
	methods["AddDnsRecords"] = "Adds a list of records to a zone.";
	methods["EditDnsRecords"] = "Changes a list of records in a zone.";
	methods["SetDnsRecords"] = "Sets the records for all matching label/type/class-triples in a zone to that specified by the records passed.";
	methods["DeleteDnsRecords"] = "Deletes a list of records from a zone.";
	methods["GetDnsRecords"] = "Fetches a list of all records for a specified zone and label.";
	methods["GetLabels"] = "Fetches a list of all labels for a specified zone.";
	methods["GetZone"] = "Fetches a complete zone from the database.";
	methods["RestoreZone"] = "Restore a complete zone (or just set all records for some other reason).";
	methods["SetDnsRecordsBulk"] = "Sets the records for all matching label/type/class-triples in a list of zones to that specified by the records passed.";
	methods["CopyDnsZoneBulk"] = "Copies a complete zone to one or more other zones, overwriting any preexisting data.";
	methods["CopyDnsLabelBulk"] = "Copies all records from a label in the source zone to the same label in one or more other zones, overwriting any preexisting data.";
	methods["DeleteDnsRecordsBulk"] = "Deletes all matching records from a list of zones. Everything except id must match for a record to be deleted.";
	methods["AddNameserver"] = "Add a nameserver as a subscriber of changes to the data set in this server.";
	methods["DeleteNameserver"] = "Remove a nameserver as a subscriber of changes to the data set in this server.";
	methods["GetChangedZones"] = "Fetches a list of all changed zones for a nameserver.";
	methods["MarkUpdated"] = "Mark a change-row as handled, removing it if no error occured.";
	methods["GetAllZones"] = "Get a list of all zones in the database.";
	methods["ReloadAllZones"] = "Mark all zones in the database as changed.";
	methods["GetUpdatesDisabled"] = "Fetch information regarding if updates are disabled or not.";
	methods["SetUpdatesDisabled"] = "Set or reset the updates disabled flag.";
	methods["GetNameserverGroup"] = "Get the nameserver group for a zone.";
	methods["SetNameserverGroup"] = "Set the nameserver group for a zone.";
	methods["AddNameserverGroup"] = "Add a nameserver group.";
	methods["DeleteNameserverGroup"] = "Removes an empty nameserver group.";
	methods["AddSlaveZone"] = "Adds a new slave zone.";
	methods["DeleteSlaveZone"] = "Removes a slave zone.";
	methods["GetChangedSlaveZones"] = "Fetches a list of all changed slave zones for a nameserver.";
	methods["MarkSlaveZoneUpdated"] = "Mark a slave zone change-row as handled, removing it if no error occured.";
	methods["GetSlaveZone"] = "Fetches information about a slave zone."
	methods["ReloadAllSlaveZones"] = "Mark all slave zones in the database as changed.";
}'

cat <<EOH
<?xml version="1.0"?>
<definitions name="AtomiaDNS"
		targetNamespace="urn:Atomia::DNS::Server"
		xmlns:tns="urn:Atomia::DNS::Server"
		xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
		xmlns:xsd="http://www.w3.org/2001/XMLSchema"
		xmlns="http://schemas.xmlsoap.org/wsdl/">

EOH

cat "$2"

faultmessages=""
for fault in LogicalError InvalidParametersError SystemError InternalError; do
	echo "\n\t<message name=\"$fault""FaultMessage\">\n\t\t<part element=\"tns:$fault""Fault\" name=\"fault\" />\n\t</message>"
	faultmessages="$faultmessages\n\t\t\t<fault message=\"tns:$fault""FaultMessage\" name=\"$fault""Fault\" />"
done

grep "=>" lib/Atomia/DNS/Server.pm | grep -E "$1" | awk -F '"' "$methodawk"'{ print "\n\t<message name=\"" $2 "Input\">\n\t\t<documentation>" methods[$2] "</documentation>\n\t\t<part name=\"parameters\" element=\"tns:" $2 "\"/>\n\t</message>\n\n\t<message name=\"" $2 "Output\">\n\t\t<part name=\"parameters\" element=\"tns:" $2 "Response\"/>\n\t</message>" }'

echo -n '\n\t<portType name="AtomiaDNSPortType">'

grep "=>" lib/Atomia/DNS/Server.pm | grep -E "$1" | awk -v faults="$faultmessages" -F '"' '{ print "\n\t\t<operation name=\"" $2 "\">\n\t\t\t<input message=\"tns:" $2 "Input\"/>\n\t\t\t<output message=\"tns:" $2 "Output\"/>" faults "\n\t\t</operation>" }'

echo '\t</portType>\n\n\t<binding name="AtomiaDNSSoapBinding" type="tns:AtomiaDNSPortType">\n\t\t<soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>'

grep "=>" lib/Atomia/DNS/Server.pm | grep -E "$1" | awk -F '"' "$methodawk"'{ print "\n\t\t<operation name=\"" $2 "\">\n\t\t\t<documentation>" methods[$2] "</documentation>\n\t\t\t<soap:operation soapAction=\"urn:Atomia::DNS::Server#" $2 "\"/>\n\t\t\t<input><soap:body use=\"literal\"/></input>\n\t\t\t<output><soap:body use=\"literal\"/></output>\n\t\t</operation>" }'

cat <<EOF
	</binding>

	<service name="AtomiaDNSService">
		<documentation>Atomia DNS Soap server</documentation>
		<port name="AtomiaDNSPort" binding="tns:AtomiaDNSSoapBinding">
			<soap:address location="http://atomiadns.soap.server/atomiadns"/>
		</port>
	</service>
</definitions>
EOF

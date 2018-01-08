%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Database schema for Atomia DNS
Name: atomiadns-database
Version: 1.1.46
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch

Requires: postgresql-server >= 8.3

%description
The Atomia DNS database schema.

%prep
%setup -n %{sourcedir}

%build

%install
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/schema
%{__cp} schema/* %{buildroot}/usr/share/atomiadns/schema
%{__cp} debian/atomiadns-database.postinst %{buildroot}/usr/share/atomiadns/atomiadns-database.postinst.sh
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/conf
%{__cp} conf/atomiadns.conf %{buildroot}/usr/share/atomiadns/conf/atomiadns-database.conf

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/share/atomiadns/schema
/usr/share/atomiadns/atomiadns-database.postinst.sh
/usr/share/atomiadns/conf/atomiadns-database.conf

%post
/usr/bin/systemctl enable postgresql
/usr/bin/systemctl daemon-reload
/usr/bin/postgresql-setup initdb > /dev/null
/usr/bin/systemctl start postgresql
sh /usr/share/atomiadns/atomiadns-database.postinst.sh

%changelog
* Tue Jan 09 2018 Zeljko Zivkovic <zeljko@atomia.com> - 1.1.46-1
- Switch to Systemd startup for RHEL
* Thu Sep 21 2017 Stefan Stankovic <stefan.stankovic@atomia.com> 1.1.45-1
- Add support for CAA
* Fri Dec 23 2016 Stefan Mortensen <stefan@atomia.com> - 1.1.44-1
- Remove apache2-mpm-prefork dependency on Ubuntu 16.04
* Mon Oct 24 2016 Oscar Linderholm <oscar@atomia.com> - 1.1.43-1
- Correctly trim white spaces from arguments in atomiadnsclient
* Fri Feb 19 2016 Jimmy Bergman <jimmy@atomia.com> - 1.1.42-1
- Fix verify_zone to treat zone_id and label_id as bigint correctly
* Fri Oct 23 2015 Jimmy Bergman <jimmy@atomia.com> - 1.1.40-1
- Fix clearing zone metadata and deletion of zones with metadata
* Thu Oct 22 2015 Jimmy Bergman <jimmy@atomia.com> - 1.1.39-1
- Allow pre-specifying database username and password in config instead of generating even with local database
* Tue Apr 07 2015 Jimmy Bergman <jimmy@atomia.com> - 1.1.36-1
- Make sure all change-methods take bigint correctly
* Tue Mar 17 2015 Jimmy Bergman <jimmy@atomia.com> - 1.1.35-1
- Fixes to make things work with Ubuntu 14.04 LTS.
* Tue Feb 03 2015 Jimmy Bergman <jimmy@atomia.com> - 1.1.34-1
- Add support for TLSA
* Fri Nov 14 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.33-1
- Allow multi string TXT records
* Mon Nov 10 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.32-1
- Allow _ in CNAME rdata to take some DKIM deployment scenarios into account
* Wed Oct 29 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.31-1
- Update PowerDNS schema for 3.4.0
* Mon Oct 27 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.30-1
- Move from Net::DNS::Zone::Parser to Net::DNS::ZoneFile::Fast
* Fri Sep 12 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.29-1
- Improve update of large DNS zones in PowerDNS sync agent
* Tue Apr 01 2014 Jimmy Bergman <jimmy@atomia.com> - 1.1.28-1
- Update id for zone, label, record, slavezone, change, slavezone_change and zone_metadata to bigint
* Tue Feb 12 2013 Jimmy Bergman <jimmy@atomia.com> - 1.1.27-1
- Fix DeleteNameserverGroup and AddSlaveZoneAuth
* Tue Jan 15 2013 Jimmy Bergman <jimmy@atomia.com> - 1.1.26-1
- Fix atomiadns-webapp on Ubuntu 12.04 LTS
* Tue Jan 08 2013 Jimmy Bergman <jimmy@atomia.com> - 1.1.25-1
- Add GetZoneMetadata and SetZoneMetadata
* Wed Nov 21 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.24-1
- Make atomiapowerdnssync import_zonefile skip NSEC* and rectify the zone
* Mon Oct 15 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.23-1
- Fix SetDnsRecords with multiple records for the same label
* Fri Sep 07 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.22-1
- Make GetZoneBulk more memory efficient
* Mon Aug 06 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.21-1
- Disallow IPv4-addresses in AAAA records
* Tue Jun 12 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.20-1
- Fix invalid MX regexp introduced a few versions ago when doing a fresh install
* Mon Jun 11 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.19-1
- Convert atomiadns-powerdnssync to upstart on debian/ubuntu
* Thu Jun 07 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.18-1
- Add relaxed 'Recommends' dependency to libshell-perl so that powerdnssync doesn't warn on 12.04
* Tue Jun 05 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.17-1
- Fix case where we have require_auth=0 and still send auth headers
* Tue Jun 05 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.16-1
- Fix the DS generation code introduced in 1.1.15
* Tue Jun 05 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.15-1
- Add GetDNSSECKeysDS to simplify integration with external systems not using Atomia Domain Registration
* Wed May 30 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.14-1
- Fix so that the webapp starts on 12.04
* Wed May 30 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.13-1
- Fix another bug in the powerdns database creation script
* Wed May 30 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.12-1
- Fix bug in powerdns database install script
* Wed May 30 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.11-1
- Change from Digest::SHA1 to Digest::SHA due to Ubuntu Precise dropping the first one
* Thu May 10 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.10-1
- Allow one letter CNAME/NS/PTR records
* Tue May 08 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.9-1
- Always use template for mktemp for portability reasons and change to non opt-out NSEC3 until powerdns supports opt-out for NSEC3
* Tue May 08 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.8-1
- Minor FreeBSD fixes
* Fri May 04 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.7-1
- Slavezone master can be IPv6 IP, database creation improvements on FreeBSD
* Tue Mar 27 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.6-1
- Fix atomiadnsclient broken in 1.1.5
* Tue Mar 27 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.5-1
- Allow you to specify username, password and config file location in atomiadnsclient
* Thu Mar 01 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.4-1
- Fix webapp soap_uri regression introduced in 1.1.2, it is now called json_uri
* Thu Mar 01 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.3-1
- Minor layout changes in the webapp again
* Thu Mar 01 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.2-1
- Minor layout changes in the webapp
* Fri Feb 17 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.1-1
- Fix problem with having atomiadns-nameserver and atomiadns-api on the same server and fix invalid apache config introduced in 1.1.0
* Tue Jan 31 2012 Jimmy Bergman <jimmy@atomia.com> - 1.1.0-1
- Add JSON API endpoint, authentication/authorization and a built in webapp client
* Sat Jan 07 2012 Jimmy Bergman <jimmy@atomia.com> - 1.0.34-1
- Fix the case which produced an SQL error when the first record in a batch was a dupe
* Tue Jan 03 2012 Jimmy Bergman <jimmy@atomia.com> - 1.0.33-1
- Filter duplicate records in powerdns agent according to RFC2181 section 5
* Thu Dec 15 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.32-1
- Set SOA-EDIT to INCEPTION-EPOCH for native DNSSEC mode
* Fri Dec 02 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.31-1
- Add missing libmime-base32-perl dependency
* Thu Dec 01 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.30-1
- Improve domainmetadata view and support NSEC + NSEC3 instead of only NSEC3NARROW
* Wed Sep 28 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.29-1
- Make DNSSEC key generation more robust and improve slave support (multi-master + TSIG) and database schema in PowerDNS agent
* Fri Sep 16 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.28-1
- Improve performance of validation trigger + indexing for large zones
* Mon Jul 18 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.27-1
- Fix powerdns database setup
* Mon Jul 18 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.26-1
- Fix powerdns database setup
* Mon Jul 18 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.25-1
- Fix powerdns database schema to include version-table forgotten in first release, and change so that powerdns syncer can run on the same server as Atomia DNS
* Wed Jun 08 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.24-1
- Fix PowerDNS sync agent to not have trailing dot in MNAME
* Thu May 05 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.23-1
- Forgot to include powerdns_sync in 1.0.22 build
* Thu Apr 21 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.22-1
- Add timeout to atomiadnsclient
* Fri Apr 15 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.21-1
- Improve powerdns installation packages
* Thu Feb 24 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.20-1
- Fix database migration for 42->43
* Thu Feb 24 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.19-1
- Fix database schema migration for 41 -> 42
* Tue Feb 22 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.18-1
- Fix DLZ sync agent
* Thu Feb 17 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.17-1
- Handle load a bit better in the API server and change dependency to apache2-mpm-prefork to avoid threading bugs.
* Thu Jan 27 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.16-1
- DNSSEC support and changing the bind-dlz syncer to only load 10000 zones per sync_updated_zones batch
* Fri Jan 21 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.15-1
- Re-release broken package
* Fri Jan 21 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.14-1
- Add configurable timeout for syncer
* Tue Jan 18 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.13-1
- Add ability to override notify IP in config per zone in afilias integration scripts
* Tue Nov 30 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.12-1
- Add support for event chain
* Mon Apr 26 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.11-1
- Remove unique constraint for slave zone master
* Thu Apr 22 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.10-1
- Fix bug with synchronizing removed zones introduced in 1.0.9
* Thu Apr 22 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.9-1
- Add MarkUpdatedBulk, MarkAllUpdatedExceptBulk and GetZoneBulk and make the sync agent use them
* Wed Mar 24 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.8-1
- Minor WSDL changes, fix so that BDB environment is only initialized by the atomiadnssync command that actually use it instead of all commands and fix removal of nameservers when there are outstanding slave zone changes
* Mon Mar 22 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.7-1
- Add RestoreZoneBulk
* Thu Mar 18 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.6-1
- Change format of get_server and change uid/gid for created named user in RPM
* Thu Mar 04 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.5-1
- Add GetNameserver SOAP-method, get_server option and improved error handing to atomiadnssync, improve NAPTR validation and fix a bug with generation of slave zone configuration
* Mon Feb 22 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.4-1
- Add support for AllowZoneTransfer
* Tue Jan 12 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.3-1
- New bind-dlz packages fixing upstream bugs
* Tue Dec 08 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.24-1
- Update apt-packages to add the runlevel links to start daemons when installing
* Mon Dec 07 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.23-1
- Improve AAAA validation
* Wed Nov 25 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.22-1
- Fix dependency issue for redhat build
* Tue Nov 24 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.21-1
- Change TXT validation to require <= 255 chars
* Fri Oct 30 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.20-1
- Add support for RestoreZoneBinary and GetZoneBinary
* Fri Oct 16 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.19-1
- Optionally allow id in AddDnsRecords
* Mon Oct 12 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.18-1
- Add MarkAllUpdatedExcept
* Tue Oct 06 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.17-1
- Fix atomiadns-dyndns upgrade functionality
* Tue Oct 06 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.16-1
- Test upgrade with the upgrade + build script
* Thu Oct 01 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.15-1
- Initial RPM package.

%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir powerdns_sync

Summary: Atomia DNS PowerDNS Sync application
Name: atomiadns-powerdnssync
Version: 1.1.24
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-powerdns_sync.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires(pre): shadow-utils
Requires: perl-Class-MOP >= 0.92

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS PowerDNS Sync application.

%prep
%setup -n %{sourcedir}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/*/*/.packlist
%{__mkdir} -p %{buildroot}/etc/init.d
%{__cp} SPECS/atomiadns-atomiapowerdnssync.init %{buildroot}/etc/init.d/atomiapowerdnssync
%{__mkdir} -p %{buildroot}/usr/share/atomia/conf
%{__cp} conf/atomiadns.conf.atomiapowerdnssync %{buildroot}/usr/share/atomia/conf/
%{__mkdir} -p %{buildroot}/usr/share/atomia/opendnssec_scripts
%{__cp} opendnssec_scripts/*.sh %{buildroot}/usr/share/atomia/opendnssec_scripts
%{__cp} schema/powerdns.sql %{buildroot}/usr/share/atomia

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiapowerdnssync
/usr/share/atomia/conf/atomiadns.conf.atomiapowerdnssync
/usr/share/atomia/opendnssec_scripts
/usr/share/atomia/powerdns.sql
/etc/init.d/atomiapowerdnssync
%{perl_vendorlib}/Atomia/DNS/PowerDNSSyncer.pm
%{perl_vendorlib}/Atomia/DNS/PowerDNSDatabase.pm
%doc %{_mandir}/man1/atomiapowerdnssync.1.gz

%post
/sbin/chkconfig --add atomiapowerdnssync

if [ -f /etc/atomiadns.conf ]; then
	if [ -z "$(grep "^powerdns" /etc/atomiadns.conf)" ]; then
		cat /usr/share/atomia/conf/atomiadns.conf.atomiapowerdnssync >> /etc/atomiadns.conf
	fi
else
	cp /usr/share/atomia/conf/atomiadns.conf.atomiapowerdnssync /etc/atomiadns.conf
fi

if [ "$1" -gt 1 ]; then
	/sbin/service atomiapowerdnssync restart
fi

exit 0

%preun
if [ "$1" = 0 ]; then
	/sbin/service atomiapowerdnssync stop
	/sbin/chkconfig --del atomiapowerdnssync 
fi
exit 0

%changelog
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
* Thu Jan 27 2011 Jimmy Bergman <jimmy@atomia.com> - 1.0.16-1
- DNSSEC support and changing the bind-dlz syncer to only load 10000 zones per sync_updated_zones batch

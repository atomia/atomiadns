%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: SOAP-server for Atomia DNS
Name: atomiadns-api
Version: 1.1.0
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires: httpd mod_perl >= 2.0 perl-Class-MOP >= 0.92

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS API is used to create, edit and delete zone data in the Atomia DNS system.

All changes done through the API will be provisioned to the nameservers that are configured in the system.

%prep
%setup -n %{sourcedir}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install
%{__rm} -f %{buildroot}%{perl_archlib}/perllocal.pod
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/*/*/.packlist
%{__rm} -f %{buildroot}%{perl_vendorlib}/Atomia/DNS/wsdl-to-confluence.pl
%{__mkdir} -p %{buildroot}/etc/httpd/conf.d
%{__cp} conf/atomiadns.conf %{buildroot}/etc
%{__cp} conf/apache-example %{buildroot}/etc/httpd/conf.d/atomiadns.conf
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/examples
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/conf
%{__cp} examples/* %{buildroot}/usr/share/atomiadns/examples
%{__cp} conf/* %{buildroot}/usr/share/atomiadns/conf
%{__mkdir} -p %{buildroot}/var/www/html
%{__cp} *.wsdl %{buildroot}/var/www/html

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace) /etc/atomiadns.conf
/etc/httpd/conf.d/atomiadns.conf
%{perl_vendorlib}/Atomia/DNS/Server.pm
%{perl_vendorlib}/Atomia/DNS/ServerHandler.pm
/usr/share/atomiadns/conf/apache-example
/usr/share/atomiadns/conf/atomiadns.conf
/usr/share/atomiadns/examples
/usr/bin/generate_private_key
/var/www/html/wsdl-atomiadns.wsdl

%post
/sbin/chkconfig --add httpd
/sbin/service httpd graceful
/usr/sbin/semanage fcontext -a -t httpd_sys_content_t /etc/atomiadns.conf
/sbin/restorecon -R -v /etc/atomiadns.conf
/usr/sbin/setsebool httpd_can_network_connect_db 1

%postun
if [ "$1" = 0 ] ; then
	/sbin/service httpd graceful
	/usr/sbin/semanage fcontext -d -t httpd_sys_content_t /etc/atomiadns.conf
	/usr/sbin/setsebool httpd_can_network_connect_db 0
fi
exit 0

%changelog
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

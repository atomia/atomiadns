%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Command line client for Atomia DNS
Name: atomiadns-client
Version: 1.0.20
Release: 1%{?dist}
License: Commercial
Group: Applications/Internet
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

Requires: perl-libwww-perl

%description
The Atomia DNS API command line client is used for connecting to the Atomia DNS SOAP server
to administer zones.

%prep
%setup -n %{sourcedir}

%build
cd client
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}
cd ..

%install
%{__rm} -rf %{buildroot}
cd client
%{__make} pure_install
cd ..
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/.packlist

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiadnsclient
/usr/bin/dnssec_zsk_rollover
%doc %{_mandir}/man1/atomiadnsclient.1.gz
%doc %{_mandir}/man1/dnssec_zsk_rollover.1.gz

%changelog
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

%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Complete master SOAP server for Atomia DNS
Name: atomiadns-masterserver
Version: 1.0.15
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch

Requires: atomiadns-api >= 1.0.15 atomiadns-database >= 1.0.15

%description
Complete master SOAP server for Atomia DNS

%prep
%setup -n %{sourcedir}

%build

%install
%{__mkdir} -p %{buildroot}

%clean
%{__rm} -rf %{buildroot}

%files

%changelog
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

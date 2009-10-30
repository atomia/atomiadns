%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Command line client for Atomia DNS
Name: atomiadns-client
Version: 0.9.20
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
%doc %{_mandir}/man1/atomiadnsclient.1.gz

%changelog
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

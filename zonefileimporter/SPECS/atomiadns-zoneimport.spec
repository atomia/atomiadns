%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir zonefileimporter

Summary: Zone file imported for Atomia DNS
Name: atomiadns-zoneimport
Version: 1.0.7
Release: 1%{?dist}
License: Commercial
Group: Applications/Internet
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-zoneimport.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

Requires: perl-libwww-perl

%description
The Atomia DNS zone file imported is used for importing zone files into the Atomia DNS SOAP server.
to administer zones.

%prep
%setup -n %{sourcedir}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}
cd ..

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/.packlist

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiadns_zoneimport
%doc %{_mandir}/man1/atomiadns_zoneimport.1.gz

%changelog
* Mon Mar 22 2010 Jimmy Bergman <jimmy@atomia.com> - 1.0.7-1
- Add RestoreZoneBulk

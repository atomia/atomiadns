%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Complete master SOAP server for Atomia DNS
Name: atomiadns-masterserver
Version: 0.9.15
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch

Requires: atomiadns-api >= 0.9.15 atomiadns-database >= 0.9.15

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
* Thu Oct 01 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.15-1
- Initial RPM package.

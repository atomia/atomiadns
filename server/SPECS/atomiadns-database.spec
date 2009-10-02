%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: Database schema for Atomia DNS
Name: atomiadns-database
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
%{__cp} schema/atomiadns.conf %{buildroot}/usr/share/atomiadns/conf

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/share/atomiadns/schema
/usr/share/atomiadns/atomiadns-database.postinst.sh

%post
/sbin/chkconfig --add postgresql
/sbin/service postgresql initdb > /dev/null
/sbin/service postgresql start 
sh /usr/share/atomiadns/atomiadns-database.postinst.sh

%changelog
* Thu Oct 01 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.15-1
- Initial RPM package.

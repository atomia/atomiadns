%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir syncer

Summary: Atomia DNS Sync application
Name: atomiadns-nameserver
Version: 0.9.19
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-syncer.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires(pre): shadow-utils
Requires: bind-dlz-bdbhpt-driver

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS Sync application.

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
%{__cp} SPECS/atomiadns-atomiadnssync.init %{buildroot}/etc/init.d/atomiadnssync
%{__mkdir} -p %{buildroot}/usr/share/atomia/conf
%{__cp} conf/atomiadns.conf.rhel %{buildroot}/usr/share/atomia/conf/atomiadns.conf.atomiadnssync
%{__mkdir} -p %{buildroot}/usr/share/atomia/conf
%{__mkdir} -p %{buildroot}/var/named/slaves/zones
%{__mkdir} -p %{buildroot}/var/named/atomiadns_bdb
%{__cp} conf/atomiadns.named.conf %{buildroot}/var/named
%{__cp} conf/empty %{buildroot}/var/named/slaves/named-slavezones.conf.local

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiadnssync
/usr/share/atomia/conf/atomiadns.conf.atomiadnssync
/etc/init.d/atomiadnssync
%{perl_vendorlib}/Atomia/DNS/Syncer.pm
%doc %{_mandir}/man1/atomiadnssync.1.gz
%attr(0640 root named) /var/named/atomiadns.named.conf
%attr(0770 root named) %dir /var/named/slaves/zones
%attr(0770 root named) %dir /var/named/atomiadns_bdb
%attr(0660 root named) /var/named/slaves/named-slavezones.conf.local

%pre
getent group named > /dev/null || groupadd -r named
getent passwd named > /dev/null || \
useradd -r -g named -d /var/named -s /sbin/nologin -c "Named user" named
exit 0

%post
/sbin/chkconfig --add atomiadnssync

if [ -f /etc/atomiadns.conf ]; then
	if [ -z "$(grep "^bdb_filename" /etc/atomiadns.conf)" ]; then
		cat /usr/share/atomia/conf/atomiadns.conf.atomiadnssync >> /etc/atomiadns.conf
	fi
else
	cp /usr/share/atomia/conf/atomiadns.conf.atomiadnssync /etc/atomiadns.conf
fi

if [ -f /etc/named.conf ] && [ -z "$(grep atomiadns.named.conf /etc/named.conf)" ]; then
	echo 'include "atomiadns.named.conf";' >> /etc/named.conf
fi

if [ "$1" -gt 1 ]; then
	/sbin/service atomiadnssync restart
fi

chgrp named /var/run/named
chmod g+w /var/run/named

exit 0

%preun
if [ "$1" = 0 ]; then
	/sbin/service atomiadnssync stop
	/sbin/chkconfig --del atomiadnssync 
fi
exit 0

%changelog
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

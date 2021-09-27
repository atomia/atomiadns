%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir bind_sync

Summary: Atomia DNS Sync application
Name: atomiadns-bindsync
Version: 1.1.52
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-syncer.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires(pre): shadow-utils
Requires: perl-Moose >= 2.0

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
%{__mkdir} -p %{buildroot}/etc/systemd
%{__mkdir} -p %{buildroot}/etc/systemd/system
%{__cp} debian/atomiadns-bindsync.service %{buildroot}/etc/systemd/system/atomiadns-bindsync.service
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
/etc/systemd/system/atomiadns-bindsync.service
%{perl_vendorlib}/Atomia/DNS/Syncer.pm
%doc %{_mandir}/man1/atomiadnssync.1.gz
%attr(0640 root named) /var/named/atomiadns.named.conf
%attr(0770 root named) %dir /var/named/slaves/zones
%attr(0770 root named) %dir /var/named/atomiadns_bdb
%attr(0660 root named) /var/named/slaves/named-slavezones.conf.local

%pre
getent group named > /dev/null || /usr/sbin/groupadd -g 25 -f -r named >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "error creating group named"
	exit 1
fi
getent passwd named > /dev/null || /usr/sbin/useradd  -u 25 -r -M -g named -s /sbin/nologin -d /var/named -c Named named >/dev/null 2>&1
if [ $? != 0 ]; then
	echo "error creating user named"
	exit 1
fi
exit 0

%post
/usr/bin/systemctl enable atomiadns-atomiadnssync

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
	/usr/bin/systemctl restart atomiadns-atomiadnssync
fi

chgrp named /var/run/named
chmod g+w /var/run/named

exit 0

%preun
if [ "$1" = 0 ]; then
	/usr/bin/systemctl stop atomiadns-atomiadnssync
	/usr/bin/systemctl disable atomiadns-atomiadnssync
fi
exit 0

%changelog
* Mon Sep 27 2021 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.52-1
- Bump version to 1.1.52
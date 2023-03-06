%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir bind_sync

Summary: Atomia DNS Bindsync application
Name: atomiadns-bindsync
Version: 1.1.58
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-syncer.tar.gz

Packager: Atomia AB <info@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires(pre): shadow-utils
Requires: perl-Moose >= 2.0 perl-Config-General perl-SOAP-Lite bind

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS Bindsync application.

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
%{__cp} conf/atomiadns.conf.rhel %{buildroot}/usr/share/atomia/conf/atomiadns.conf.atomiabindsync
%{__mkdir} -p %{buildroot}/usr/share/atomia/conf
%{__mkdir} -p %{buildroot}/var/named
%{__cp} conf/atomiadns.named.conf.rhel %{buildroot}/usr/share/atomia/conf/atomiadns.named.conf

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiabindsync
/usr/share/atomia/conf/atomiadns.conf.atomiabindsync
/etc/systemd/system/atomiadns-bindsync.service
%{perl_vendorlib}/Atomia/DNS/Syncer.pm
%doc %{_mandir}/man1/atomiabindsync.1.gz
%attr(0640 root named) /usr/share/atomia/conf/atomiadns.named.conf

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
/usr/bin/systemctl enable atomiadns-bindsync

if [ -f /etc/atomiadns.conf ]; then
	if [ -z "$(grep "^slavezones_config" /etc/atomiadns.conf)" ]; then
		cat /usr/share/atomia/conf/atomiadns.conf.atomiabindsync >> /etc/atomiadns.conf
	fi
else
	cp /usr/share/atomia/conf/atomiadns.conf.atomiabindsync /etc/atomiadns.conf
fi

if [ -f /etc/named.conf ] && [ -z "$(grep 'atomiadns.named.conf' /etc/named.conf)" ]; then
	echo 'include "/var/named/atomiadns.named.conf";' >> /etc/named.conf
fi

if [ "$1" -gt 1 ]; then
	/usr/bin/systemctl restart atomiadns-bindsync
fi

chgrp named /var/run/named
chmod g+w /var/run/named

if [ ! -f "/etc/rndc.key" ]; then
	/usr/sbin/rndc-confgen -a
	chown root:named /etc/rndc.key
	chmod 640 /etc/rndc.key
	service named restart
fi

mkdir -p /var/named/slaves/zones
chmod 770 /var/named/slaves/zones
chown root:named /var/named/slaves/zones

touch /var/named/tsig_keys.conf
chmod 660 /var/named/tsig_keys.conf
chown root:named /var/named/tsig_keys.conf

touch /var/named/slaves/named-slavezones.conf.local
chmod 660 /var/named/slaves/named-slavezones.conf.local
chown root:named /var/named/slaves/named-slavezones.conf.local

cp -fp /usr/share/atomia/conf/atomiadns.named.conf /var/named/atomiadns.named.conf

exit 0

%preun
if [ "$1" = 0 ]; then
	/usr/bin/systemctl stop atomiadns-bindsync
	/usr/bin/systemctl disable atomiadns-bindsync
fi
exit 0

%changelog
* Mon Mar 06 2023 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.58-1
- Add support for RHEL8
- Change binary to atomiabindsync
- Service name changed to atomiadns-bindsync
- Fix path consistency between RHEL and Ubuntu for bind slave zones
- Autogenerate rndc.key on package install if the key doesn't already exist
- Fix conflicting config files between atomiadns-bindsync and bind nameserver
- Fix missing dependencies
- Changed app name in log files to atomiabindsync
- Bump version to 1.1.58
* Mon Oct 10 2022 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.57-1
- Bump version to 1.1.57
* Wed Dec 08 2021 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.56-1
- Bump version to 1.1.56
* Wed Oct 13 2021 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.55-1
- Bump version to 1.1.55
* Tue Oct 12 2021 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.54-1
- Bump version to 1.1.54
* Tue Oct 05 2021 Jovana Stamenkovic <jovana.stamenkovic@atomia.com> - 1.1.53-1
- Bump version to 1.1.53
* Mon Sep 27 2021 Nemanja Zivkovic <nemanja.zivkovic@atomia.com> - 1.1.52-1
- Bump version to 1.1.52

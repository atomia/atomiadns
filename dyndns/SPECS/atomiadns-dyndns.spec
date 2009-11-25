%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir dyndns

Summary: Atomia DNS DDNS server
Name: atomiadns-dyndns
Version: 0.9.22
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-dyndns.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS DDNS server.

%prep
%setup -n %{sourcedir}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/.packlist
%{__mkdir} -p %{buildroot}/usr/share/atomia/patches/Net/DNS
%{__cp} patches/Net-DNS-Nameserver-UpdateHandler.patch %{buildroot}/usr/share/atomia/patches
%{__cp} patches/Net/DNS/Nameserver.pm %{buildroot}/usr/share/atomia/patches/Net/DNS
%{__mkdir} -p %{buildroot}/etc/init.d
%{__cp} SPECS/atomiadns-dyndns.init %{buildroot}/etc/init.d/atomiadyndns
%{__mkdir} -p %{buildroot}/usr/share/atomia/conf
%{__cp} conf/atomiadns.conf %{buildroot}/usr/share/atomia/conf/atomiadns.conf.atomiadyndns

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/bin/atomiadyndns
/usr/share/atomia/patches/Net-DNS-Nameserver-UpdateHandler.patch
/usr/share/atomia/patches/Net/DNS/Nameserver.pm
/usr/share/atomia/conf/atomiadns.conf.atomiadyndns
/etc/init.d/atomiadyndns

%post
/sbin/chkconfig --add atomiadyndns

if [ -f /etc/atomiadns.conf ]; then
	if [ -z "$(grep "^tsig_key" /etc/atomiadns.conf)" ]; then
		cat /usr/share/atomia/conf/atomiadns.conf.atomiadyndns >> /etc/atomiadns.conf
	fi
else
	cp /usr/share/atomia/conf/atomiadns.conf.atomiadyndns /etc/atomiadns.conf
fi

if [ "$1" = 1 ]; then
	/sbin/service atomiadyndns start
else
	/sbin/service atomiadyndns restart
fi

exit 0

%preun
if [ "$1" = 0 ]; then
	/sbin/service atomiadyndns stop
	/sbin/chkconfig --del atomiadyndns
fi
exit 0

%changelog
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

%define perl_vendorlib %(eval "`%{__perl} -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`%{__perl} -V:installvendorarch`"; echo $installvendorarch)

%define sourcedir server

Summary: SOAP-server for Atomia DNS
Name: atomiadns-api
Version: 0.9.18
Release: 1%{?dist}
License: Commercial
Group: System Environment/Daemons
URL: http://www.atomia.com/atomiadns/
Source: atomiadns-server.tar.gz

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires: httpd mod_perl >= 2.0

BuildArch: noarch
BuildRequires: perl
BuildRequires: perl(ExtUtils::MakeMaker)

%description
Atomia DNS API is used to create, edit and delete zone data in the Atomia DNS system.

All changes done through the API will be provisioned to the nameservers that are configured in the system.

%prep
%setup -n %{sourcedir}

%build
%{__perl} Makefile.PL INSTALLDIRS="vendor" PREFIX="%{buildroot}%{_prefix}"
%{__make} %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}
%{__make} pure_install
%{__rm} -f %{buildroot}%{perl_archlib}/perllocal.pod
%{__rm} -f %{buildroot}%{perl_vendorarch}/auto/*/*/*/.packlist
%{__rm} -f %{buildroot}%{perl_vendorlib}/Atomia/DNS/wsdl-to-confluence.pl
%{__mkdir} -p %{buildroot}/etc/httpd/conf.d
%{__cp} conf/atomiadns.conf %{buildroot}/etc
%{__cp} conf/apache-example %{buildroot}/etc/httpd/conf.d/atomiadns.conf
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/examples
%{__mkdir} -p %{buildroot}/usr/share/atomiadns/conf
%{__cp} examples/* %{buildroot}/usr/share/atomiadns/examples
%{__cp} conf/* %{buildroot}/usr/share/atomiadns/conf
%{__mkdir} -p %{buildroot}/var/www/html
%{__cp} *.wsdl %{buildroot}/var/www/html

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace) /etc/atomiadns.conf
/etc/httpd/conf.d/atomiadns.conf
%{perl_vendorlib}/Atomia/DNS/Server.pm
%{perl_vendorlib}/Atomia/DNS/ServerHandler.pm
/usr/share/atomiadns/conf/apache-example
/usr/share/atomiadns/conf/atomiadns.conf
/usr/share/atomiadns/examples/atomiadnsclient.pl
/usr/share/atomiadns/examples/atomiadnsclient_wsdl.pl
/var/www/html/wsdl-atomiadns.wsdl

%post
/sbin/chkconfig --add httpd
/sbin/service httpd graceful
/usr/sbin/semanage fcontext -a -t httpd_sys_content_t /etc/atomiadns.conf
/sbin/restorecon -R -v /etc/atomiadns.conf
/usr/sbin/setsebool httpd_can_network_connect_db 1

%postun
if [ "$1" = 0 ] ; then
	/sbin/service httpd graceful
	/usr/sbin/semanage fcontext -d -t httpd_sys_content_t /etc/atomiadns.conf
	/usr/sbin/setsebool httpd_can_network_connect_db 0
fi
exit 0

%changelog
* Mon Oct 12 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.18-1
- Add MarkAllUpdatedExcept
* Tue Oct 06 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.17-1
- Fix atomiadns-dyndns upgrade functionality
* Tue Oct 06 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.16-1
- Test upgrade with the upgrade + build script
* Thu Oct 01 2009 Jimmy Bergman <jimmy@atomia.com> - 0.9.15-1
- Initial RPM package.

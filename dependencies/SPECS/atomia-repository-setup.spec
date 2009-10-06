Summary: Atomia RPM Repository setup and public key
Name: atomia-repository-setup
Version: 1.0
Release: 1%{?dist}
License: Commercial
Group: System Environment/Base
URL: http://rpm.atomia.com/atomia-repository-setup.noarch.rpm

Packager: Jimmy Bergman <jimmy@atomia.com>
Vendor: Atomia AB RPM Repository http://rpm.atomia.com/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch

%description
Atomia RPM Repository setup and public key

%prep

%build

%install
%{__rm} -rf %{buildroot}

%{__mkdir} -p %{buildroot}/etc/pki/rpm-gpg
%{__cat} > %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-ATOMIA <<EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.5 (GNU/Linux)

mQGiBErLANYRBACF9Cr/1HZH7En5pb8MqeL8k3zjQyhQRJd1yzY8+9gFMUldAJow
nWfYDrupSHOgCxlv54lZmBL4HpaxEcpjgab+ZzBC8e8xpkV818gH34f6PE96HahG
FZEWLbQLxXo7MQeAClSzECUalHEWx0K0iXmluUCBoRa/EUB8xcIis4tZ7wCguk7/
6Kakz4DWUl8tuyfr+wtZq0MD/35cZ/qXKoLhZdr7RHeAyIsqh1fv6L31zjfP/N2l
wBIGuQ974R9cgpdyKaF24HpUvQSw24obTB87YWU7mlB006viQ+P99nYM3AUKfFLw
mPdAR6YSbK7S7SUc27jA0/eaO86PAj8QBnF1gO0m6I8OXMbnDbdBClCI7JQAjbEX
E7kaA/0dJqmH0wfSpAb48ncJ44pu2ojrsZH5dUcpsTiXSKuUXLGfk4uoaH39w5gv
whNoWuxYblntcyCDrLnL6ZU5ws4o8OGSBuZMryXJJvvVz+7G3ldLBq48j7XEOHgH
Ok0LebVzpq/bVCr3NLD9XIWDEROKp/TSSD15rUc3wyko7HWY1bQnQXRvbWlhIFJQ
TSBSZXBvc2l0b3J5IDxpbmZvQGF0b21pYS5jb20+iGAEExECACAFAkrLANYCGwMG
CwkIBwMCBBUCCAMEFgIDAQIeAQIXgAAKCRBCi1LahzlXk9v6AKCtIE5u/Xq1TdcK
uk/1qfbWFLo1HACfbnnQouHWTJLHhe4aJ/TyO/YNIcO5Ag0ESssA4BAIALW2SnQk
PaMQSZg2wQxpA5NijI5ndVxaMkfDO07UD2EWp8VWirVhtTwpY2LwrsLEfEItrinT
eos1MFTPyp/hqJNwoDTN/npNElZIuMvyX+/hhbjHe5oqhdsMmEXEs+Es9DijIlW+
05GJkQZYI//VDrkb+9+VHRZbVe39x9vF19HdwVJXPJHnxrjKyca3FebV0z+tncxm
6zCBgfkH3wmaBajo59o/Amo/1bM3whP6hsYcAoYE0forv4/C6MOGCA53V8jT7Moj
lkDmzMO2X046T6MYuKqhZNhmZ+A7dFcaIXBRLf7X5aMv0S0v+VXARao3phnIyxKN
pS/9TQxHsDR48HMAAwYH/1HxVch8saGr97nZ21XwHKbGOVMz/GrB+mvexq+Y4oHp
/kGWSxeh6VnCcrHujpYVySc/x2EH9ebzPHzPHr7hGj1WpB2Sw6/tjF6YbNd5Duht
Imi28YgkU7LH0+AoOUPDzzDOxod3hOj4cGPb5fXNc3BPaPOJwC6TegBGu0rIYXy0
d39e91D/wn3QbDDZsWDkObki7VnBkfxET+yW8VG6h+66irh/NPEaIigK4W44VeuF
ApP/XLL2Rf3/qT0PPTEGJPIBFVH/Z77DsgpWjL5DcJuncfablHGypbweJUpRF7Ti
Jxs9td3EyVVc4RP54wuqZMORdmr6oEQDdUTLf8+Nf/+ISQQYEQIACQUCSssA4AIb
DAAKCRBCi1LahzlXk+ItAJ0S8mssO7Oe0BUsvqHsMIFE7JVsEACeOwLkCWAmMpTW
Qim0s9K0fyFPHnw=
=qQ4Y
-----END PGP PUBLIC KEY BLOCK-----
EOF

%{__mkdir} -p %{buildroot}/etc/yum.repos.d
%{__cat} > %{buildroot}/etc/yum.repos.d/atomia-rhel5.repo <<EOF
[atomia]
name=Atomia RHEL5 RPM Repository
baseurl=http://rpm.atomia.com/rhel5/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ATOMIA
EOF

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
/etc/pki/rpm-gpg/RPM-GPG-KEY-ATOMIA
/etc/yum.repos.d/atomia-rhel5.repo

%post
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-ATOMIA

%changelog
* Thu Oct 06 2009 Jimmy Bergman <jimmy@atomia.com> - 1.0
- Initial RPM package.

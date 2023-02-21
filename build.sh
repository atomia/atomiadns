#!/bin/sh

rm -f *.deb *.rpm

distributor=`awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release | tr -d '"'`

if [ -z "$distributor" ]; then
        echo "lsb_release -i failed to give distro identifier"
        exit 1
elif [ x"$distributor" = x"Ubuntu" -o x"$distributor" = x"Debian" ]; then
        ./build-apt.sh
	exit $?
elif [ x"$distributor" = x"RedHatEnterpriseServer" -o x"$distributor" = x"CentOS" -o x"$distributor" = x"AlmaLinux" ]; then
        ./build-rpm.sh
	exit $?
fi

#!/bin/sh

rm -f *.deb *.rpm

# Fix for OS that does not have lsb_release
which lsb_release
if [ $? -ne 0 ]; then
        distributor=`awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release | tr -d '"'`
else
        distributor=`lsb_release -i | awk '{ print $NF }'`
fi

if [ -z "$distributor" ]; then
        echo "lsb_release -i failed to give distro identifier"
        exit 1
elif [ x"$distributor" = x"Ubuntu" -o x"$distributor" = x"Debian" ]; then
        ./build-apt.sh
	exit $?
elif [ x"$distributor" = x"RedHatEnterpriseServer" -o x"$distributor" = x"CentOS" -o x"$distributor" = x"AlmaLinux" -o x"$distributor" = x"CentOS Linux" -o x"$distributor" = x"Red Hat Enterprise Linux Server" ]; then
        ./build-rpm.sh
	exit $?
fi

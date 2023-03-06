#!/bin/bash

# Helper functions for building RPM packages
function build_rpm_helper {
    OS="$1"
    PACKAGES="$2"

    OS_VERSION=`echo "$OS" | awk '{print tolower($0)}' | awk -Frhel '{ print $2 }'`
    echo "INFO: OS is $OS"
    for PACKAGE_SPEC in $PACKAGES; do
        PACKAGE_NAME=`echo $PACKAGE_SPEC | awk -F. '{ print $1 }'`
        echo "INFO: Running rpmbuild for $PACKAGE_NAME"
        if [ "$OS_VERSION" -lt 8 ]; then
            # Build and sign pacakages in older RHEL versions
            rpmbuild --sign -ba "$PACKAGE_SPEC"
            if [ $? -ne 0 ]; then
                echo "ERROR: Could not run rpmbuild!"
                exit $ret
            fi
        else
            # Build packages
            rpmbuild -ba "$PACKAGE_SPEC"
            if [ $? -ne 0 ]; then
                echo "ERROR: Could not run rpmbuild!"
                exit $ret
            fi
            # Sign built package
            echo "INFO: Signing package"
            rpm --addsign /usr/src/redhat/RPMS/*/"$PACKAGE_NAME"*.rpm
            if [ $? -ne 0 ]; then
                echo "ERROR: Could not sign package!"
                exit $ret
            fi
        fi
    done
}
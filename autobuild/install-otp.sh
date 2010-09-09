#!/bin/bash

# Download, build and install a given version of OTP into
# #HOME/otp-VERSION

set -e -x

version=$1

if [ ! -f $HOME/otp-$version/.ok ] ; then
    rm -rf $HOME/otp-$version/.ok
    cd /var/tmp
    [ -f otp_src_$version.tar.gz ] || wget http://erlang.org/download/otp_src_$version.tar.gz
    rm -rf otp_src_$version
    tar xzf otp_src_$version.tar.gz
    cd otp_src_$version
    { ./configure --prefix=$HOME/otp-$version 2>&1 && touch .configure-ok ; } | tee /var/tmp/otp-$version.log
    test -e .configure-ok
    { make 2>&1 && touch .make-ok ; } | tee -a /var/tmp/otp-$version.log
    test -e .make-ok
    { make install 2>&1 && touch .make-install-ok ; } | tee -a /var/tmp/otp-$version.log
    test -e .make-install-ok
    cd /var/tmp
    rm -rf otp_src_$version
    touch $HOME/otp-$version/.ok
fi

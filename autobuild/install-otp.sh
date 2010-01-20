#!/bin/sh

set -e -x

install_otp () {
    version=$1

    if [ ! -d ~/otp-$version ] ; then
        cd /var/tmp
        [ -f otp_src_$version.tar.gz ] || wget http://erlang.org/download/otp_src_$version.tar.gz
        rm -rf otp_src_$version
        tar xzf otp_src_$version.tar.gz
        cd otp_src_$version
        ./configure --prefix=$HOME/otp-$version 2>&1 | tee /var/tmp/otp-$version.log
        make 2>&1 | tee -a /var/tmp/otp-$version.log
        make install 2>&1 | tee -a /var/tmp/otp-$version.log
        cd /var/tmp
        rm -rf otp_src_$version
    fi
}

install_otp R11B-5
install_otp R12B-5


#!/bin/bash

# Download, build and install a given version of OTP into
# #HOME/otp-VERSION

set -e -x

version=$1
extras=$2

if [ $(uname -s) = 'Darwin' ]; then
    # Add Homebrew prefix to the PATH.
    export PATH="/usr/local/bin:$PATH"

    # Use OpenSSL from Homebrew.
    with_ssl='--with-ssl=/usr/local/opt/openssl'
fi

if [ ! -f $HOME/otp-$version/.ok ] ; then
    rm -rf $HOME/otp-$version/.ok
    mkdir -p $HOME/tmp-otp-build
    cd $HOME/tmp-otp-build
    [ -f otp_src_$version.tar.gz ] || wget http://erlang.org/download/otp_src_$version.tar.gz
    rm -rf otp_src_$version
    tar xzf otp_src_$version.tar.gz
    cd otp_src_$version
    { ./configure --prefix=$HOME/otp-$version $with_ssl $extras 2>&1 && touch .configure-ok ; } | tee $HOME/tmp-otp-build/otp-$version.log
    test -e .configure-ok
    { make 2>&1 && touch .make-ok ; } | tee -a $HOME/tmp-otp-build/otp-$version.log
    test -e .make-ok
    { make install 2>&1 && touch .make-install-ok ; } | tee -a $HOME/tmp-otp-build/otp-$version.log
    test -e .make-install-ok
    cd $HOME/tmp-otp-build
    rm -rf otp_src_$version
    touch $HOME/otp-$version/.ok
fi

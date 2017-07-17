#!/bin/sh
# vim:sw=4:et:

set -ex

version=$1

if [ ! -f $HOME/elixir-$version/.ok ] ; then
    rm -rf $HOME/elixir-$version/.ok
    mkdir -p $HOME/tmp-elixir-build
    cd $HOME/tmp-elixir-build
    rm -rf elixir_$version
    git clone https://github.com/elixir-lang/elixir.git --branch v$version elixir_$version
    cd elixir_$version
    { make 2>&1 && touch .make-ok ; } | tee -a $HOME/tmp-elixir-build/elixir-$version.log
    test -e .make-ok
    { make install PREFIX="$HOME/elixir-$version" 2>&1 && touch .make-install-ok ; } | tee -a $HOME/tmp-elixir-build/elixir-$version.log
    test -e .make-install-ok
    cd $HOME/tmp-elixir-build
    rm -rf elixir_$version
    touch $HOME/elixir-$version/.ok
fi

#!/bin/bash

mkdir -p _repo/logs
{
    . `dirname $0`/buildlib.sh

    clean_all
    fetch_all
    clean_all
    # ^^ yes, again. Things may have changed after the fetch
    build_all
} 2>&1 | tee _repo/logs/build.log.`date +%Y%m%d%H%M%S`.txt

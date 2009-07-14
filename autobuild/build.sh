#!/bin/bash

. `dirname $0`/buildlib.sh

clean_all
fetch_all
clean_all
# ^^ yes, again. Things may have changed after the fetch
build_all

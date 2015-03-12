#!/bin/sh

set -e

target=$1
branch=$2

project=$(basename $(git remote -v | head -n1 | awk '{ print $2 }') | sed 's/\.git$//')

if git branch -a | grep -q "$branch"; then
	if ! (git branch -a --merged "$target" | grep -q "$branch"); then
		echo "$project: branch $branch NOT merged to $target"
	fi
fi

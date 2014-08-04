#!/bin/sh
program=$1
shift
symbols=$(echo "$@" | sed 's/ /\\\|/g')
if test $(file -L -b --mime-type "$program") == "application/x-executable" && readelf -r "$program" | grep -e "$symbols" >/dev/null ; then
    echo "$program"
    exit 1
fi
exit 0

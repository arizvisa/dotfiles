#!/bin/sh
ARGV0=$0

expand_archive()
{
    if [ $# -ne 2 ]; then
        return 1
    fi

    name=$1
    target=$2
    /c/Windows/SysWOW64/expand.exe '-F:*' "$name" "$target"
}

basename()
{
    echo "$1" | sed 's/\.[^.]\+$//'
}

help()
{
    echo "usage: $ARGV0 file.{msu,cab} [target]" 1>&2
}

if [ $# -lt 1 ]; then
    help
    exit
fi

name=$1
target=$2
if [ -z "$target" ]; then
    target=$(basename "$name")
fi

target=$(readlink -f $target)

mkdir -p "$target"
expand_archive "$name" "$target"

echo "Extracted files to $target"

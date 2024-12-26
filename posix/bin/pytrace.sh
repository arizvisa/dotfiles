#!/usr/bin/env bash
if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/python/binary/ [bpftrace-parameters...]" 1>&2
    exit 22 # EINVAL
fi

if ! type -P "$1"; then
    echo "$0: $1: No such file or directory"
    exit 2  # ENOENT
fi

PY=`type -P "$1"`
if [ ! -x "$PY" ]; then
    echo "$0: $PY: Permission denied"
    exit 13 # EACCESS
fi

read library < <(ld.so --list "$PY" | gawk '$1 ~ /^libpython/ {print $3}')
read fp < <( realpath -q "/usr/$library" )
sudo bpftrace -e 'usdt:'"$fp"':python:function__entry {time("%H:%M:%S"); printf(" line filename=%s, funcname=%s, lineno=%d\n", str(arg0), str(arg1), arg2);}' "$@"

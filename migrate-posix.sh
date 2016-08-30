#!/bin/sh
path=`dirname "$0"`
if test "$#" -ne 1; then
    echo "Usage: $0 target" 1>&2
    echo "Symbolically links the contents of $path/posix into the directory specified by target."
    exit 1
fi
fullpath=`readlink -f "$path"`

find "$fullpath/posix" -mindepth 1 -maxdepth 1 -print | while read p; do
    base=`basename "$p"`
    echo ln -sf "$p" "$1/$base"
    ln -sf "$p" "$1/$base"
done

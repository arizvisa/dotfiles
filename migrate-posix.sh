#!/bin/sh
path=`dirname "$0"`
if test "$#" -ne 1; then
    echo "Usage: $0 target" 1>&2
    echo "Symbolically links the contents of $path/posix into the directory specified by target."
    exit 1
fi

find $path/posix -mindepth 1 -maxdepth 1 -print | while read n; do
    echo ln -sf "$n" "$1"
    ln -sf "$n" "$1"
done

#!/bin/sh
posix=vim
pf_x86=`env | egrep "^ProgramFiles\(x86\)" | cut -d= -f2-`
pf_x64="${ProgramFiles}"
pf=`cygpath "${pf_x64}"`
windows=`ls -1 "$pf"/Vim/gvim.exe 2>/dev/null`

## determine which program to run
case "$platform" in
    msys|cygwin)
        prog=`[ -x "$windows" ] && echo "$windows"`
        ;;
esac

## if it's not found, then search the path
if [ -z "$prog" ]; then
    argv0=`readlink -f "$0"`
    IFS=:
    for p in $PATH; do
        rp=`readlink -f "$p/$posix"`
        [ -x "$rp" ] && [ `stat -f%i "$argv0" 2>/dev/null || echo "$argv0"` != `stat -f%i "$rp" 2>/dev/null || echo "$rp"` ] && prog="$rp"
    done
fi

# go for it...or not.
[ -z "$prog" ] && echo "Unable to locate $posix" 1>&2 && exit 1
"$prog" "$@"
exit $?

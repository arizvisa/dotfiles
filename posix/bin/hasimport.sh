#!/bin/sh
if [ $# -lt 2 ] || ! tty -s; then
    echo "usage: $0 program regex..." 1>&2
    exit 22 # EINVAL
fi

program=$1
shift
symbols=`printf '%s\n' "$@" | sed 's/\n/\\\|/g'`

mime=`file -L -b --mime-type "$program"`
case $mime in
    application/x-executable|application/x-pie-executable)
        ok=3    # ESRCH
        while IFS=' ' read offset info type value symbol; do
            printf '%s\t%#x\t%s\t%#x\t%s\n' "$program" "0x$offset" "$type" "0x$value" "$symbol"
            ok=0
        done < <( readelf -Wr "$program" | grep -e ' R' | grep -e "$symbols" )
        exit $ok
    ;;
    *)
        echo "$0: unknown mime type: $mime" 1>&2
    ;;
esac
exit 8 # ENOEXEC

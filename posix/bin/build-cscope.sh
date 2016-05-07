#!/bin/sh
cscope=$(which cscope)

usage()
{
    printf "usage: %s [-h] [-?] [--help] [[-f filter1]...] directory1...\n" "$1"
    printf "builds a cscope database in each directory specified at the commandline\n"
    printf "if a filter isn't specified, then use '*.c' and '*.h'\n"
}

args=`getopt -u -o h\?f: -l help -- $*`
if [ "$?" -ne 0 ]; then
    usage "$0" 1>&2
    exit 1
fi

filter=
set -- $args
while [ "$#" -gt "0" ]; do
    case "$1" in
        -h|-\?|--help)
            usage "$0"
            exit 0
            ;;
        -f)
            filter="$filter '$2'"
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ "$filter" = "" ]; then
    filter="'*.c' '*.h'"
fi

if [ "$#" -eq 0 ]; then
    printf "%s: building cscope database for %s\n" "$0" "$filter"
    ( for glob in $filter; do eval find ./ -type f -a -name $glob; done ) | $cscope -b -v -i-
    exit $?
fi

for path in "$@"; do
    printf "%s: building cscope database for %s in %s\n" "$0" "$filter" "$path"
    ( cd "$path" && for glob in $filter; do
        eval find ./ -type f -a -name $glob
    done | $cscope -b -v -i- )
done


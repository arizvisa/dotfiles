#!/usr/bin/env bash
arg0=`basename "$0"`
usage()
{
    printf "usage: %s [-h] [-?] [[-f filter1]...] directory1...\n" "$1"
    printf "builds a cscope database in each directory specified at the commandline.\n"
    printf "if a filter isn't specified, then use \"'*.c' '*.h' '*.cc' '*.cpp' '*.hpp'\".\n"
    printf "if \$CSPROG isn't defined, then use \"%s\" to build database.\n" "cscope -b -v -i-"
}

filter=
while getopts hf: opt; do
    case "$opt" in
        h|\?)
            usage "$arg0"
            exit 0
            ;;
        f)
            printf "%s: adding filter : %s\n" "$arg0" "$OPTARG"
            [ "$filter" = "" ] && filter="$OPTARG" || filter="$filter $OPTARG"
            ;;
    esac
done
shift `expr "$OPTIND" - 1`

if [ "$filter" = "" ]; then
    filter="*.c *.h *.cc *.cpp *.hpp"
    printf "%s: using filter : %s\n" "$arg0" "$filter"
fi

if [ "$CSPROG" = "" ]; then
    cscope=$(which cscope)
    command="$cscope -b -v -i-"
else
    command="$CSPROG"
fi

if [ "$#" -eq 0 ]; then
    printf "%s: building cscope database : %s\n" "$arg0" "$filter"
    ( echo "$filter " | while read -d' ' glob; do find ./ -type f -a -name "$glob"; done ) | $command
    exit $?
fi

for path in "$@"; do
    if [ ! -d "$path" ]; then
        printf "%s: skipping invalid path : %s\n" "$arg0" "$path"
        continue
    fi
    printf "%s: building cscope database : %s\n" "$arg0" "$path"
    ( cd -- "$path" && echo "$filter " | while read -d' ' glob; do
        find ./ -type f -a -name "$glob"
    done | $command )
done


#!/usr/bin/env bash
arg0=`basename "$0"`
usage()
{
    printf "usage: %s [-h] [-?] [[-f filter1]...] directory1...\n" "$1"
    printf "builds a cscope database in each directory specified at the commandline.\n\n"
    printf "if a filter isn't specified, then use \"'*.c' '*.h' '*.cc' '*.cpp' '*.hpp'\".\n\n"
    printf "if \$CSPROG isn't defined, then use \"%s\" to build database.\n" "cscope -b -v -i-"
}

declare -a filter
while getopts hf: opt; do
    case "$opt" in
        h|\?)
            usage "$arg0"
            exit 0
            ;;
        f)
            printf "%s: adding filter : %s\n" "$arg0" "$OPTARG"
            filter=( "${filter[@]}" "$OPTARG" )
            ;;
    esac
done
shift `expr "$OPTIND" - 1`

if [ -z "$filter" ]; then
    filter=(\*.c \*.h \*.cc \*.cpp \*.hpp)
    printf "%s: using filter : %s\n" "$arg0" "${filter[*]}"
fi

if [ -z "$CSPROG" ]; then
    CSPROG=`type -P gtags || type -P cscope`
fi

csprog=`basename "$CSPROG"`
case "$csprog" in
cscope|cscope.*)
    description="cscope"
    printf "%s: using cscope to build database\n" "$arg0"
    command="$csprog -b -v -i-"
    ;;
gtags|gtags.*)
    description="gnu global"
    printf "%s: using gtags to build database\n" "$arg0"
    command="$csprog --accept-dotfiles --explain -c -v -f-"
    ;;
*)
    printf "%s: unsupported tag program was specified : %s\n" "$arg0" "$CSPROG"
    exit 1
esac

if [ "$#" -eq 0 ]; then
    printf "%s: building %s database : %s\n" "$arg0" "$description" "${filter[*]}"
    for glob in "${filter[@]}"; do
        find ./ -type f -a -name "$glob"
    done | $command
    exit $?
fi

for path in "$@"; do
    if [ ! -d "$path" ]; then
        printf "%s: skipping invalid path : %s\n" "$arg0" "$path"
        continue
    fi
    printf "%s: building %s database : %s\n" "$arg0" "$description" "$path"
    ( cd -- "$path" && for glob in "${filter[@]}"; do
        find ./ -type f -a -name "$glob"
    done | $command )
done


#!/usr/bin/env bash
ARG0=`basename "$0"`
usage()
{
    printf "usage: %s [-h] [-?] [-l] [[-f language filter1]...] [[-x filter1]...] directory1...\n" "$1"
    printf "builds a cscope database in each directory specified at the commandline.\n"
    printf "if a filter isn't specified, then use \"'*.c' '*.h' '*.cc' '*.cpp' '*.hpp'\".\n"
    printf "if \$CSPROG isn't defined, then use \"%s\" to build database.\n" "cscope -b -v -i-"
}

### command-specific utilities
global_langmap()
{
    "$csprog" --config=langmap | while read -d, item; do
        IFS=: read language extensions <<< "$item"
        printf '%s\t%s\n' "$language" "$extensions"
    done
}

global_skip()
{
    "$csprog" --config=skip | while read -d, item; do
        printf '%s\n' "$item"
    done
}

tc_build_label()
{
    label="$1"
    shift
    printf '%s:' "$label"
    printf ':%s' "$@"
    printf ':\n'
}

tc_build_skip()
{
    label="$1"
    shift
    printf '%s:' "$label"
    printf ':skip='
    printf '%s\0' "$@" | paste -zsd, - | xargs -0 printf "%s:\n"
}

tc_build_langmap_content()
{
    language="$1"
    shift
    printf ':langmap=%s\:' "$language"
    xargs -0 printf '(%s)'
}

tc_build_langmap_header()
{
    label="$1"
    shift
    printf '%s:\\\n\t' "$label"
}

tc_build_langmap_footer()
{
    label="$1"
    shift
    printf ':'
}

# XXX: i think i was testing adding support for arbitrary languages here
global_build_test()
{
    tc_build_label "fucker" "tc=exclude" "tc=include"
    tc_build_skip "exclude" "GPATH" "GRTAGS" "GTAGS" "*.h"
    #printf "%s\0" '*.cc' '*.cpp' '*.x' '' 1>&3
    #tc_build_langmap "include" 'cpp' $'*.c\0*.cc\0*.cc' #'php' $'*.php\n*.php3' "c\n*.c\n*.h\n'
    clang=( "*.cc" "*.cpp" "*.c" "" )
    plang=( "*.php" "*.php3" )

    tc_build_langmap_header 'include'
    printf '%s\0' "${clang[@]}" | tc_build_langmap_content cpp
    printf '%s\0' "${plang[@]}" | tc_build_langmap_content php
    tc_build_langmap_footer 'include'
}

### command-detection utilities
choose_command()
{
    program="$1"
    path="$2"
    case "$program" in
    cscope|cscope.*)
        symbol="cscope"
        ;;
    gtags|gtags.*)
        symbol="global"
        ;;
    *)
        printf '%s: unsupported tag program was specified : %s\n' "$ARG0" "$path" 1>&2
        exit 1
    esac
    echo "$symbol"
}

cscope_description()
{
    echo "cscope"
}
global_description()
{
    echo "gnu global"
}

### define explicit commands that the user can use via the parameters

## list the available languages that the user is allowed to map globs to
global_list_languages()
{
    global_langmap "$@"
}

cscope_list_languages()
{
    printf '%s: unable to list languages for the detected program (%s)\n' "$ARG0" "$description"
    exit 1
}

## build the database for each tag program type
global_build_database()
{
    printf '%s: using gtags to build database\n' "$ARG0"
    generic_build_database "$csprog --accept-dotfiles --explain -c -v -f-" "$@"
}

cscope_build_database()
{
    printf '%s: using cscope to build database\n' "$ARG0"
    generic_build_database "$csprog -b -v -i-" "$@"
}

# generic function to build the database for both tag programs
generic_build_database()
{
    command="$1"
    shift 1

    printf 'processing directory: %s\n' "$@"
    printf 'running with: "%s"\n' "$command"
    exit 1

    # if we were given no directories, then we start with the invocation directory.
    if [ "$#" -eq 0 ]; then
        printf '%s: building %s database : %s\n' "$ARG0" "$description" "${filter[*]}"
        for glob in "${filter[@]}"; do
            find ./ -type f -a -name "$glob"
        done | $command
        exit $?
    fi

    # otherwise we iterate through our parameters adding them one-by-one.
    for path in "$@"; do
        if [ ! -d "$path" ]; then
            printf '%s: skipping invalid path : %s\n' "$ARG0" "$path"
            continue
        fi
        printf '%s: building %s database : %s\n' "$ARG0" "$description" "$path"
        ( cd -- "$path" && for glob in "${filter[@]}"; do
            find ./ -type f -a -name "$glob"
        done | $command )
    done
}

### now we can begin the actual logic of the script that figures out what
### the user is trying to do and how we'll need to do it.

## first we need to figure out which program we need to use for making tags
if [ -z "$CSPROG" ]; then
    CSPROG=`type -P gtags || type -P cscope`
fi
csprog=`basename "$CSPROG"`
cmd=`choose_command "$csprog" "$CSPROG"`
[ "$?" -gt 0 ] && exit "$?"

# assign some variables to help with emitting error and status messages
description=`eval $cmd\_description`

## now we can process our command line parameters
declare -a filter
operation=build_database
#operation=build_test

while getopts hlf: opt; do
    case "$opt" in
        h|\?)
            usage "$ARG0"
            exit 0
            ;;
        l)
            operation=list_languages
            ;;
        f)
            printf '%s: adding filter : %s\n' "$ARG0" "$OPTARG"
            filter=( "${filter[@]}" "$OPTARG" )
            ;;
    esac
done
shift `expr "$OPTIND" - 1`

eval "$cmd\_$operation"

exit 1  # XXX

### we're dead after this
## default filter to use when processing things
if [ "$filter" = "" ]; then
    filter=(*.c *.h *.cc *.cpp *.hpp)
    printf '%s: using filter : %s\n' "$ARG0" "${filter[*]}"
fi

## let the invoker know how we're going to build their database
case "$csprog" in
cscope|cscope.*)
    description="cscope"
    ;;
gtags|gtags.*)
    description="gnu global"
    printf '%s: using gtags to build database\n' "$ARG0"
    command="$csprog --accept-dotfiles --explain -c -v -f-"
    ;;
*)
    printf '%s: unsupported tag program was specified : %s\n' "$ARG0" "$CSPROG"
    exit 1
esac

#global_langmap
#exit 1

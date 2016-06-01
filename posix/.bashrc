#
# Local-user rc file for bash(1).
#

set -o noclobber
set -o ignoreeof
set -o vi

## aliases and complete
unalias -a
complete -r

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

alias l=`which less || which more`
alias info="`which info` --vi-keys"

# because some fucks alias `ls` to `ls -g`
alias ls 2>/dev/null && unalias ls

## platform-specific fixes
if [ "$platform" == "Darwin" ]; then
    readlink() { greadlink "$@"; }
    export -f readlink
fi

## default files
if [ ! -e "$HOME/.inputrc" ]; then
    echo 'set editing-mode vi' > "$HOME/.inputrc"
fi

## useful functions
fman()
{
    cat "$@" | groff -t -c -mmandoc -Tascii
}

termdump()
{
     infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read n; do printf "%s -- %s\n" "$n" "`man -w 5 terminfo | xargs zcat | egrep -A 2 \"\b$n[^[:print:]]\" | tr -d '\n' | sed 's/T{/{/g;s/T}/}/g' | egrep -m1 -o '\{[^}]+\}' | tr -d '\n'`"; done
}

alias addcscope=__addcscope
alias rmcscope=__rmcscope

__addcscope()
{
    [ "$#" -eq "0" ] && path="`pwd`/cscope.out" || path="$@"

    current_db="$CSCOPE_DB"
    for p in $path; do
        [ -d "$p" ] && p="$p/cscope.out"
        p=`readlink -m "$p"`
        if [ ! -e "$p" ]; then
            printf "Unable to locate cscope database: %s\n" "$p" 1>&2
            continue
        fi
        ft=`file -b "$p" | grep -oe "^[^ ]\+"`
        if [ "$ft" != "cscope" ]; then
            printf "Invalid file magic for %s: %s\n" "$p" "$ft" 1>&2
            continue
        fi
        printf "Adding path to CSCOPE_DB: %s\n" "$p" 1>&2
        [ "$current_db" = "" ] && current_db="$p" || current_db="$current_db:$p"
    done
    export CSCOPE_DB="$current_db"
    unset current_db ft p
    return 0
}

__rmcscope()
{
    [ "$#" -eq "0" ] && cull=`pwd` || cull="$@"

    current_db=
    for n in `echo "$CSCOPE_DB" | tr ':' "\n"`; do
        if [ ! -e "$n" ]; then
            printf "Removing missing cscope database from CSCOPE_DB: %s\n" "$n" 1>&2
            continue
        fi

        found=0
        for p in $cull; do
            [ -d "$p" ] && p="$p/cscope.out"
            nabs=`readlink -f "$n"`
            pabs=`readlink -f "$p"`

            if [ "$nabs" == "$pabs" ]; then
                found=`expr "$found" + 1`
            fi
        done

        if [ "$found" -gt 0 ]; then
            printf "Removing cscope database from CSCOPE_DB: %s\n" "$n" 1>&2
        else
            [ "$current_db" = "" ] && current_db="$n" || current_db="$current_db:$n"
        fi
    done
    export CSCOPE_DB="$current_db"
    unset cull current_db n p nabs pabs found
    return 0
}

# devtodo specific
command devtodo >/dev/null 2>&1
if [ "$?" -eq 0 ]; then
    todo_options='--timeout --summary'
    cd()
    {
        builtin cd "$@" && [ -r .todo ] && devtodo $todo_options
    }

    pushd()
    {
        builtin pushd "$@" && [ -r .todo ] && devtodo $todo_options
    }

    popd()
    {
        builtin pushd "$@" && [ -r .todo ] && devtodo
    }
fi

## useful functions
addpythonpath()
{
    path=`resolvepath "$1"`
    if [ "$?" -gt 0 ]; then
        echo "addpythonpath: directory "$1" does not exist" 1>&2
        return 1
    fi
    shift

    [ -z "$PYTHONPATH" ] && PYTHONPATH="$path" || PYTHONPATH="$path:$PYTHONPATH"
    export PYTHONPATH

    [ "$#" -gt 0 ] && addpythonpath "$@"
}

addpath()
{
    path=`resolvepath "$1"`
    if [ "$?" -gt 0 ]; then
        echo "addpath: directory "$1" does not exist" 1>&2
        return 1
    fi
    shift

    [ -z "$PATH" ] && PATH="$path" || PATH="$path:$PATH"
    export PYTHONPATH

    [ "$#" -gt 0 ] && addpath "$@"
}

## execute local specific bash stuff
[ -e "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"

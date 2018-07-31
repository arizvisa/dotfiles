#
# Local-user rc file for bash(1).
#

# if .profile hasn't been executed yet, then do it first.
[ -z "$PROFILE" ] && source "$HOME/.profile"

# verify challenge from .profile
[ "$1" != "$HOME/.bashrc" ] && return
export rcfile="$HOME/.bashrc"

# prefix $HOME/bin to PATH
[ -e "$HOME/bin" ] && PATH="$HOME/bin:$PATH"

# set some default options for bash
set -o noclobber
set -o ignoreeof
set -o vi

## aliases and complete
unalias -a
complete -r

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

alias l="`type -p less || type -p more`"
alias info="`type -p info` --vi-keys"

# because some fucks alias `ls` to `ls -g`
alias ls 2>/dev/null && unalias ls

## platform-specific fixes
if [ "$platform" == "Darwin" ]; then
    readlink() { greadlink "$@"; }
    export -f readlink
fi

## default files
if [ ! -e "$HOME/.inputrc" ]; then
    echo 'set editing-mode vi' >| "$HOME/.inputrc"
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

__addcscope()
{
    local listsep
    [ "${os}" = "windows" ] && listsep=";" || listsep=":"

    [ "$#" -eq "0" ] && path="`pwd`/cscope.out" || path="$@"
    local current_db p
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
        local np
        [ "${os}" = "windows" ] && np=`cygpath -w "$p"` || np="$p"
        printf "Adding path to CSCOPE_DB: %s\n" "$np" 1>&2
        [ "$current_db" = "" ] && current_db="$np" || current_db="$current_db""${listsep}""$np"
    done
    export CSCOPE_DB="$current_db"
    return 0
}

__rmcscope()
{
    [ "${os}" = "windows" ] && listsep=";" || listsep=":"
    [ "$#" -eq "0" ] && cull=`pwd` || cull="$@"

    local nn np
    local nabs pabs

    local current_db=
    for nn in `echo "$CSCOPE_DB" | tr "${listsep}" "\n"`; do
        local n
        [ "${os}" = "windows" ] && n=`cygpath "$nn"` || n="$nn"

        if [ ! -e "$n" ]; then
            printf "Removing missing cscope database from CSCOPE_DB: %s\n" "$n" 1>&2
            continue
        fi

        found=0
        for np in $cull; do
            local p
            [ "${os}" = "windows" ] && p=`cygpath "$np"` || p="$np"

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
            [ "$current_db" = "" ] && current_db="$nn" || current_db="$current_db""${listsep}""$nn"
        fi
    done
    export CSCOPE_DB="$current_db"
    unset cull found
    return 0
}

alias addcscope=__addcscope
alias rmcscope=__rmcscope

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
    export PATH

    [ "$#" -gt 0 ] && addpath "$@"
}

## execute local specific bash stuff
[ -e "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"

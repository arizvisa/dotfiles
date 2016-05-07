#
# Local-user rc file for bash(1).
#

set -o noclobber
set -o ignoreeof
set -o vi

# aliases and complete
unalias -a
complete -r

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

alias l=$(which less)
alias info="$(which info) --vi-keys"

# because some fucks alias `ls` to `ls -g`
alias ls 2>/dev/null && unalias ls

# default files
if test ! -e "$HOME/.inputrc"; then
    echo 'set editing-mode vi' > "$HOME/.inputrc"
fi

# useful functions
fman()
{
    cat $@ | /usr/bin/gtbl | /usr/bin/nroff -Tascii -c -mandoc
}

alias addcscope=__addcscope
alias rmcscope=__rmcscope

__addcscope()
{
    test "$#" -eq "0" && path="`pwd`/cscope.out" || path="$@"

    current_db="$CSCOPE_DB"
    for p in $path; do
        test -d "$p" && p="$p/cscope.out"
        p=`readlink -m "$p"`
        if test ! -e "$p"; then
            printf "Unable to locate cscope database: %s\n" "$p" 1>&2
            continue
        fi
        ft=`file -b "$p" | grep -oe "^[^ ]\+"`
        if test "$ft" != "cscope"; then
            printf "Invalid file magic for %s: %s\n" "$p" "$ft" 1>&2
            continue
        fi
        printf "Adding path to CSCOPE_DB: %s\n" "$p" 1>&2
        test "$current_db" = "" && current_db="$p" || current_db="$current_db:$p"
    done
    export CSCOPE_DB="$current_db"
    unset current_db ft p
    return 0
}

__rmcscope()
{
    test "$#" -eq "0" && cull=`pwd` || cull="$@"

    current_db=
    for n in `echo "$CSCOPE_DB" | tr ':' "\n"`; do
        if test ! -e "$n"; then
            printf "Removing missing cscope database from CSCOPE_DB: %s\n" "$n" 1>&2
            continue
        fi

        found=0
        for p in $cull; do
            test -d "$p" && p="$p/cscope.out"
            nabs=`readlink -f "$n"`
            pabs=`readlink -f "$p"`

            if test "$nabs" == "$pabs"; then
                found=`expr "$found" + 1`
            fi
        done

        if test "$found" -gt 0; then
            printf "Removing cscope database from CSCOPE_DB: %s\n" "$n" 1>&2
        else
            test "$current_db" = "" && current_db="$n" || current_db="$current_db:$n"
        fi
    done
    export CSCOPE_DB="$current_db"
    unset cull current_db n p nabs pabs found
    return 0
}

# devtodo specific
command devtodo >/dev/null 2>&1
if test "$?" -eq 0; then
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
resolvepath()
{
    path=$1
    shift

    if test -z "$path"; then
        path=$(pwd)
    fi

    path=$(readlink -f "$path")

    if test ! -d "$path"; then
        return 1
    fi

    echo "$path"
}

addpythonpath()
{
    path=$(resolvepath "$1")
    if test "$?" -gt 0; then
        echo "addpythonpath: directory "$1" does not exist" 1>&2
        return 1
    fi
    shift

    if test -z "$PYTHONPATH"; then
        PYTHONPATH="$path"
    else
        PYTHONPATH="$path:$PYTHONPATH"
    fi
    export PYTHONPATH

    if test $# -gt 0; then
        addpythonpath $@
    fi
}

addpath()
{
    path=$(resolvepath "$1")
    if test "$?" -gt 0; then
        echo "addpath: directory "$1" does not exist" 1>&2
        return 1
    fi
    shift

    if test -z "$PATH"; then
        PATH="$path"
    else
        PATH="$path:$PATH"
    fi
    export PYTHONPATH

    if test $# -gt 0; then
        addpath $@
    fi
}

## execute local specific bash stuff
[ -e $HOME/.bashrc.local ] && source $HOME/.bashrc.local

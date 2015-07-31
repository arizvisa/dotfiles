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

alias pivot='export CSCOPE_DIR=$(pwd); export CSCOPE_DB=$CSCOPE_DIR/cscope.out;'
alias unpivot='unset CSCOPE_DIR; unset CSCOPE_DB;'
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

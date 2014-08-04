#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).

set -o noclobber
set -o ignoreeof
set -o vi
umask 022

# TODO:
#   assign $USER if undefined
#   assign $HOME if undefined
#   resolve ~/ to $HOME if possible
#   move xMsys specific environment elsewhere

# strip all slashes at end of home
export HOME=$(echo -n "$HOME" | sed 's/\/*$//')
export PATH="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin:$PATH"
export PS1='[\!] \u@\h \w$ '

if test x$(uname -o) == xMsys; then
    export PATH="$PATH:/c/Python27"
    export PATH="$PATH:$PROGRAMFILES/Vim/vim73"
    export PATH="$PATH:$PROGRAMFILES/OpenSSL/bin"
    export PATH="$PATH:$PROGRAMFILES/Microsoft SDKs/Windows/v7.0A/Bin"

else
    export EDITOR=$(which vim)
    export PERL5LIB="$HOME/.perl/share/perl/5.8.8"

    ulimit -c unlimited
    #ulimit -t 60
    #ulimit -v 1048576
    #ulimit -u 256

fi

## upgrade terminal
case "$TERM" in
    dumb) TERM=ansi ;;
    xterm) TERM=xterm-256color ;;
    gnome-terminal) TERM=gnome-256color ;;
    *-256color) TERM=$TERM ;;
    linux) TERM=linux ;;
    cygwin) TERM=ansi ;;
    *) echo "~/.bashrc : Unknown login terminal type ($TERM)" 1>&2 ;;
esac
export TERM

## upgrade language locale to unicode
if test "$LANG" == ""; then
    export LANG=en_US.UTF-8
fi

## default tmpdir
if test "$TMPDIR" == ""; then
    export TMPDIR="$HOME/tmp"
    test -d "$TMPDIR" || mkdir -p "$TMPDIR"
fi

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
if test -e "$HOME/.bashrc.local"; then
    . $HOME/.bashrc.local
fi

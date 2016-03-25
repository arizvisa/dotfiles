#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).
umask 022

# TODO:
#   assign $USER if undefined
#   assign $HOME if undefined
#   resolve ~/ to $HOME if possible
#   move xMsys specific environment elsewhere

# strip all slashes at end of home
export HOME=$(echo -n "$HOME" | sed 's/\/*$//')
export PS1='[\!] \u@\h \w$ '

path="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin"

# decompose path, and add only the paths that exist.
oldpath="$PATH"
path=`echo "${path}" | while read -d: p; do [ -d "${p}" ] && echo -n "${p}:"; done`
PATH=`echo "${path}" | sed 's/:$//'`
PATH="${PATH}:${oldpath}"
unset oldpath path
export PATH

if test x$(uname -o) == xMsys; then
    export EDITOR=`which vim`
    export programfiles=`cygpath "$PROGRAMFILES"`

    # fix a bug with msys2, that actually comes from an older version of cygwin.
    if test `uname -r | cut -d. -f 1` == 2; then
        export PATH=`echo "${PATH}" | sed 's/\(:\/bin:\)/:\/usr\/bin\1/'`
    fi
else
    export EDITOR=`which vim`
    export PERL5LIB="$HOME/.perl/share/perl/5.8.8"

    ulimit -c unlimited
    #ulimit -t 60
    #ulimit -v 1048576
    #ulimit -u 256
fi

## promote terminal to something colorful
case "$TERM" in
    dumb) TERM=ansi ;;
    xterm) TERM=xterm-256color ;;
    gnome-terminal) TERM=gnome-256color ;;
    *-256color) TERM=$TERM ;;
    linux) TERM=linux ;;
    cygwin) TERM=ansi ;;
    *) echo "$0 : Unknown login terminal type ($TERM)" 1>&2 ;;
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
export TMP="$TMPDIR"

## go home, john
cd "$HOME"

## continue adding stuff from .bashrc
[ -e $HOME/.bashrc ] && source $HOME/.bashrc

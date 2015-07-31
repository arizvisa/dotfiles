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
export PATH="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin:$PATH"
export PS1='[\!] \u@\h \w$ '

if test x$(uname -o) == xMsys; then
    export EDITOR=$(which vim)
    export programfiles=`cygpath "$PROGRAMFILES"`
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

## go home
cd "$HOME"

## continue adding stuff from .bashrc
[ -e $HOME/.bashrc ] && source $HOME/.bashrc

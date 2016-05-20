#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).
umask 022

# TODO:
#   assign $HOME if undefined
#   resolve ~/ to $HOME if possible
#   move xMsys specific environment elsewhere

[ -z "$USER" ] && export USER=`whoami`
[ -z "$HOME" ] && export HOME=`( cd && pwd -P )`
export HOME=`echo "$HOME" | sed 's/\/*$//'`     # strip all slashes at end of home
export PS1='[\!] \u@\h \w$ '

path="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin"

# decompose path, and keep only the paths that exist.
oldpath="$PATH"
path=`echo "${path}" | while read -d: p; do [ -d "${p}" ] && echo -n "${p}:"; done`
PATH=`echo "${path}" | sed 's/:$//'`
PATH="${PATH}:${oldpath}"
unset oldpath path
export PATH

## set language locale to utilize utf-8 encoding
if [ "$LANG" == "" ]; then
    export LANG=en_US.UTF-8
fi

## default tmpdir
if [ "$TMPDIR" == "" ]; then
    export TMPDIR="$HOME/tmp"
    [ -d "$TMPDIR" ] || mkdir -p "$TMPDIR"
fi
export TMP="$TMPDIR"

## global variables/settings
export EDITOR=`which vim`
ulimit -c unlimited
ulimit -u 384 2>/dev/null

## platform-specific stuff
export platform=`uname -o 2>/dev/null || uname -s 2>/dev/null`
case "$platform" in
    Msys|Cygwin)
        export programfiles=`cygpath "$PROGRAMFILES"`

        # fix a bug with msys2, that actually comes from an older version of cygwin.
        if [ `uname -r | cut -d. -f 1` == 2 ]; then
            export PATH=`echo "${PATH}" | sed 's/\(:\/bin:\)/:\/usr\/bin\1/'`
        fi
        ;;
    *)
        if [ -d "$HOME/.perl" ]; then
            perlver=`perl -V:VERSION | cut -d\' -f2 | cut -d. -f 1,2`
            export PERL5LIB="$HOME/.perl/share/perl/$perlver"
            unset perlver
        fi

        #ulimit -t 60
        #ulimit -v 1048576
        ;;
esac

## promote terminal to something colorful
case "$TERM" in
    *-256color) TERM=$TERM ;;
    xterm) TERM=xterm-256color ;;
    gnome-terminal) TERM=gnome-256color ;;
    dumb) TERM=ansi ;;

    linux) TERM=linux ;;
    cygwin) TERM=ansi ;;
    *) echo "$0 : Unknown login terminal type ($TERM)" 1>&2 ;;
esac
export TERM

## go home, john
cd "$HOME"

## continue loading stuff from .bashrc
[ -e $HOME/.bashrc ] && source $HOME/.bashrc

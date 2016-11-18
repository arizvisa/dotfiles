#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).
umask 022

# set a global so that .bashrc can verify this rcfile has been executed already.
export PROFILE=`[ ! -z "$USERPROFILE" ] && echo "$USERPROFILE" || echo "$HOME"`
if [ ! -d "$PROFILE" ]; then
    # FIXME: programmatically determine the tmp directory in case $PROFILE fails.
    export PROFILE="/tmp/`id -u`"
    echo "Unable to determine profile directory. Defaulting to \"$PROFILE\"." 1>&2
fi

[ -z "$USER" ] && export USER=`whoami`
[ -z "$HOME" ] && export HOME=`( cd "$PROFILE" && pwd -P )`

export HOME=`( cd "$HOME" && pwd -P )`   # clean up the path
export PS1='[\!] \u@\h \w$ '

path="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin"

# decompose path, and keep only the paths that exist.
# FIXME: figure out bourne-specific way to replace sed here so we don't have to depend on the path.
oldpath="$PATH"
path=`echo "${path}" | while read -d: p; do [ -d "${p}" ] && echo -n "${p}:"; done`
PATH="${path%:}"
PATH="${PATH}:${oldpath}"
unset oldpath path
export PATH

## set language locale to utilize utf-8 encoding
if [ -z "$LANG" ]; then
    export LANG=en_US.UTF-8
fi

## default tmpdir
if [ -z "$TMPDIR" ]; then
    export TMPDIR="$HOME/tmp"
    [ -d "$TMPDIR" ] || mkdir -p "$TMPDIR"
fi
export TMP="$TMPDIR"

## global variables/settings
export EDITOR=`type -p vim`
ulimit -c unlimited
ulimit -u 384 2>/dev/null

## platform-specific stuff
IFS=- read arch model platform <<< "${MACHTYPE}"
export arch model platform

case "$platform" in
    msys|cygwin)
        # windows variables
        export ProgramFiles="${ProgramFilesW6432:-$PROGRAMFILES}"
        export ProgramFiles_x86_=`env | egrep '^ProgramFiles\(x86\)=' | cut -d= -f2-`

        # figure out msys/cygwin root
        export Root=`mount | cut -d' ' -f 1,3,5 | awk '$2 == "/"' | cut -d' ' -f 1`

        # figure out mingw's root according to the arch
        case "$arch" in
        x86_64) Mingw="${Root}/mingw64" ;;
        x86) Mingw="${Root}/mingw32" ;;
        esac
        export Mingw

        # fix a bug when compiling on msys2, that actually came from some older version of cygwin and still remains.
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

        # FIXME: add support for python's user-local site-packages

        #ulimit -t 60
        #ulimit -v 1048576
        ;;
esac

case "$OS" in
    Windows*) os="windows" ;;
    *) os="posix" ;;
esac
export os

## promote terminal to something colorful
case "$TERM" in
    *-256color) TERM="$TERM" ;;
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
[ -e "$HOME/.bashrc" ] && source "$HOME/.bashrc"

#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).
umask 022

## set a global so that .bashrc can verify this rcfile has been executed already.
export PROFILE=`[ ! -z "$USERPROFILE" ] && echo "$USERPROFILE" || echo "$HOME"`
if [ ! -d "$PROFILE" ]; then
    # FIXME: programmatically determine the tmp directory in case $PROFILE fails.
    export PROFILE="/tmp/`id -u`"
    echo "$0 : Unable to determine profile directory. Defaulting to \"$PROFILE\"." 1>&2
fi

## Figure out the user and home directory if it hasn't been set yet
[ -z "$USER" ] && export USER=`whoami`
[ -z "$HOME" ] && export HOME=`( cd "$PROFILE" && pwd -P )`

## Normalize some of the environment variables
export HOME=`( cd "$HOME" && pwd -P )`   # clean up the path

#path="$HOME/bin:/sbin:/usr/sbin:/usr/pkg/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/pkg/bin:/usr/local/bin"

## decompose path, and keep only the paths that exist.
oldpath="$PATH"
path=`echo "${path}" | while read -r -d: p; do [ -d "${p}" ] && echo -n "${p}:"; done`
PATH="${path%:}"
PATH="${PATH}:${oldpath}"
unset oldpath path
export PATH

## set language locale to utilize utf-8 encoding
[ -z "$LANG" ] && export LANG=en_US.UTF-8

## default tmpdir
[ -z "$TMPDIR" ] && TMPDIR="$HOME/tmp"
[ -d "$TMPDIR" ] || (
    echo "$0 : Unable to find temporary directory. Making a temporary directory at \"$TMPDIR\"." 1>&2;
    mkdir -p "$TMPDIR"
)
TMP="$TMPDIR"
TEMP="$TMPDIR"
export TMPDIR TMP TEMP

## platform auto-detection
IFS=- read arch model platform <<< "${MACHTYPE}"
export arch model platform

## os detection
case "$OS" in
    Windows*) os="windows" ;;
    *) os="posix" ;;
esac
export os

## detect the distribution using lsb_release
if [ -e "/etc/os-release" ]; then
    distro=
    distro_version=
    while IFS='=' read key value; do
        [ "$key" == "ID" ] && distro="$value"
        [ "$key" == "VERSION_ID" ] && distro_version="$value"
    done < /etc/os-release
    [ "$distro" == "" ] && echo "$0 : Unable to determine the platform distro from /etc/os-release." 1>&2
    [ "$distro_version" == "" ] && echo "$0 : Unable to determine the platform distro version from /etc/os-release." 1>&2
    export distro distro_version
fi

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

## platform-specific variables
case "$platform" in
    msys|cygwin)
        # windows environment variables
        export ProgramFiles="${ProgramW6432:-$PROGRAMFILES}"

        ProgramFiles_x86_=
        while IFS== read -r key value; do
            [ "$key" == "ProgramFiles(x86)" ] && ProgramFiles_x86_="$value"
        done < <( env )
        export ProgramFiles_x86_
        [ "$ProgramFiles_x86_" == "" ] && echo "$0 : Unable to remap environment variable \"ProgramFiles(x86)\" to \"ProgramFiles_x86_\"." 1>&2

        # figure out msys/cygwin root
        Root=
        while IFS=' ' read source _ target _ fs options; do
            [ "$target" == "/" ] && Root="$source"
        done < <( mount )
        export Root
        [ "$Root" == "" ] && echo "$0 : Unable to determine msys/cygwin root from \"mount\" command." 1>&2

        # figure out mingw's root according to the arch
        case "$arch" in
        x86_64) export Mingw="${Root}/mingw64" ;;
        x86)    export Mingw="${Root}/mingw32" ;;
        *) echo "$0 : Unable to determine path for \"Mingw\" due to unsupported architecture ($arch)." 1>&2 ;;
        esac

        # fix a bug with paths wrt compiling on msys2 which originated from some older version of cygwin and still remains.
        IFS='.()' read rmajor rminor rpatch _ < <( uname -r )
        if [ "$rmajor" -eq "2" ]; then
            export PATH=`sed 's/\(:\/bin:\)/:\/usr\/bin\1/' <<< "$PATH"`
        fi
        unset rmajor rminor rpatch
        ;;
    linux-gnu)
        if [ -d "$HOME/.perl" ]; then
            IFS="=;'" read name q perlversion q _ < <( perl -V:version )
            if [ "$name" == "version" ]; then
                export PERL5LIB="$HOME/.perl/share/perl/$perlversion"
            else
                echo "$0 : Unable to determine Perl version" 1>&2
            fi
            unset name perlversion q
        fi

        # FIXME: add support for python's user-local site-packages
        ;;
    *)
        echo "$0 : Unsupported platform \"$platform\"." 1>&2
        ;;
esac

## global variables
export EDITOR=`type -p vim || type -p vi`
ulimit -c unlimited

## global limits
case "$os" in
posix)
    # ubuntu is fucking busted with process limits for some reason
    [ "$distro" != "ubuntu" ] && ulimit -u 1024 >/dev/null
    ulimit -t 60
    #ulimit -v 1048576
    ;;

windows)
    ulimit -u 384 2>/dev/null
    ;;
esac

## go home, john
cd "$HOME"

## continue loading stuff from .bashrc if $rcfile does not match
[ -e "$HOME/.bashrc" ] && source "$HOME/.bashrc"

#	$NetBSD: profile,v 1.1 1997/06/21 06:07:39 mikel Exp $
#
# System-wide .profile file for sh(1).
umask 022

## set a global so that .bashrc can verify this rcfile has been executed already.
export PROFILE=`[ ! -z "${USERPROFILE:-}" ] && echo "$USERPROFILE" || echo "$HOME"`
if [ ! -d "$PROFILE" ]; then
    # FIXME: programmatically determine the tmp directory in case $PROFILE fails.
    export PROFILE="/tmp/`id -u`"
    echo "$0 : Unable to determine profile directory. Defaulting to \"$PROFILE\"." 1>&2
fi

## Figure out the user and home directory if it hasn't been set yet
[ -z "${USER:-}" ] && export USER=`id -un`
[ -z "${HOME:-}" ] && export HOME=`( cd "$PROFILE" && pwd -P )`

## Normalize some of the environment variables
export HOME=`( cd "$HOME" && pwd -P )`   # clean up the path

path="$HOME/bin:$HOME/.local/bin:/usr/pkg/sbin:/opt/homebrew/sbin:/usr/local/sbin:/usr/sbin:/sbin:/usr/pkg/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

## decompose path, and keep only the paths that exist.
oldpath="${PATH:-}"
if [ "${BASH_VERSION:-empty}" = 'empty' ]; then
    path=`echo "${oldpath}\n${path}" | tr ':' $'\n' | while read component; do [ -d "${component}" ] && echo -n "${component}:"; done`
    path="${path%%:}"

# combine our specified path along with the distro path.
else
    # first we will read our desired path in order, while marking all of the
    # paths that are being used so that we can avoid duplicates.
    IFS=: read -a ordered <<<"$path"
    declare -A used
    declare -a requiredpath=()
    for index in "${!ordered[@]}"; do
        item="${ordered[$index]}"
        requiredpath+=( "$item" )
        used["$item"]=1
    done
    unset item index ordered

    # next we will read the the distro path while ignoring the ones that we
    # marked when we specified the require path.
    IFS=: read -a ordered <<<"$oldpath"
    declare -a distropath=()
    for index in "${!ordered[@]}"; do
        item="${ordered[$index]}"
        if [ -z "${used[$item]}" ]; then
            distropath+=( "$item" )
        fi
    done
    unset item index ordered

    # now we iterate through both the required paths and then the distro paths.
    declare -A available
    declare -a newpath=()
    for component in "${requiredpath[@]}" "${distropath[@]}"; do
        if [ ! -z "$component" ] && [ -z "${available[$component]}" ] && [ -d "$component" ]; then
            available[$component]=1
            newpath+=( "$component" )
        fi
    done
    unset component available distropath requiredpath used

    # then we can recompose the path in the correct order
    declare path="${newpath[0]:-}"
    let index=1
    while [ "$index" -lt "${#newpath[@]}" ]; do
        path="${path}:${newpath[$index]}"
        let index++
    done
    unset index newpath
fi
export PATH="$path"
unset path

## set language locale to utilize utf-8 encoding
[ -z "${LANG:-}" ] && export LANG=en_US.UTF-8

## default tmpdir
[ -z "${TMPDIR:-}" ] && TMPDIR="$HOME/tmp"
[ -d "$TMPDIR" ] || (
    echo "$0 : Unable to find temporary directory. Making a temporary directory at \"$TMPDIR\"." 1>&2;
    mkdir -p "$TMPDIR"
)
TMP="$TMPDIR"
TEMP="$TMPDIR"
export TMPDIR TMP TEMP

## platform auto-detection
if [ "${BASH_VERSION:-empty}" != 'empty' ]; then
    #IFS=- read arch model platform <<< "${MACHTYPE}"
    arch=`echo ${MACHTYPE} | cut -d- -f1`
    model=`echo ${MACHTYPE} | cut -d- -f2`
    platform=`echo ${MACHTYPE} | cut -d- -f3-`

# not bourne-again (linux)
elif [ "`uname -s | tr A-Z a-z`" == 'linux' ]; then
    arch=`uname -m`
    platform=`uname -o | awk -v OFS=- -v FS=/ '{ print $2, $1) }' | sed 's/^-//'`

# not bourne-again (berkeley)
else
    arch=`uname -p`
    platform=`uname -s`

fi
arch=`echo $arch | tr A-Z a-z`
model=`( uname -i 2>/dev/null || echo unknown ) | tr A-Z a-z`
platform=`echo $platform | tr A-Z a-z`
export arch model platform

## os detection

# Windows defines the OS environment variable, so we can do this pretty cheaply
case "${OS:-unknown}" in
    Windows*) os="windows" ;;
    *) os="posix" ;;
esac
export os

# detect the distribution using os-release
if [ -e "/etc/os-release" ]; then
    distro=`( grep '^ID=' /etc/os-release 2>/dev/null || uname -i ) | cut -d= -f2-`
    distro_version=`( grep '^VERSION_ID=' /etc/os-release 2>/dev/null || uname -r | cut -d- -f1 ) | tr -d '"' | cut -d= -f2-`
    export distro distro_version
fi

## promote terminal to something colorful
case "${TERM:-missing-environment-variable}" in
    *-256color) TERM="$TERM" ;;
    xterm) TERM=xterm-256color ;;
    gnome-terminal) TERM=gnome-256color ;;
    dumb) TERM=ansi ;;

    linux) TERM=linux ;;
    cygwin) TERM=ansi ;;
    missing-environment-variable) echo "$0 : Missing environment variable (TERM)" 1>&2 ;;
    *) echo "$0 : Unknown login terminal type ($TERM)" 1>&2 ;;
esac
export TERM

## platform-specific variables
case "$platform" in

    # windows environment variables
    msys|cygwin)
        export ProgramFiles="${ProgramW6432:-$PROGRAMFILES}"

        ProgramFiles_x86_=
        while IFS== read -r key value; do
            [ "$key" == "ProgramFiles(x86)" ] && ProgramFiles_x86_="$value"
        done < <( env )
        unset key value
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
        if [ "$rmajor" -ge "2" ]; then
            export PATH=`sed 's/\(:\/bin:\)/:\/usr\/bin\1/' <<< "$PATH"`
        fi
        unset rmajor rminor rpatch
        ;;

    linux|linux-gnu)
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

    darwin*)
        export BASH_SILENCE_DEPRECATION_WARNING=1   # FIRST BLOOD!
        ;;

    # Nothing necessary to do here because this platform is PERFECT.
    freebsd*)
        ;;

    *)
        echo "$0 : Unsupported platform \"$platform\"." 1>&2
        ;;
esac

## global variables
export EDITOR=`which vim 2>/dev/null || which vi 2>/dev/null || which sam 2>/dev/null || which ed 2>/dev/null`
ulimit -c unlimited

# because python devers are fucking retarded: https://github.com/python/cpython/issues/118840
# ...and here's @ambv being a lame dick about it: https://github.com/python/cpython/issues/119034
# ...and here's some lulz as a result of the rewrite: https://github.com/python/cpython/issues/125140
export PYTHON_BASIC_REPL=1

## global limits
case "$os" in
    # ubuntu is fucking busted with process limits for some reason
    posix)
        if [ "$distro" != "ubuntu" ]; then
            ulimit -Su 8192 2>/dev/null
        fi

        # some desktops (KDE) use a ton of vmem for its command-line tools
        if [ "${XDG_CURRENT_DESKTOP:-}" != "KDE" ]; then
            ulimit -Sv 104857600 2>/dev/null
        fi
        ;;

    windows)
        ulimit -Su 512 2>/dev/null
        ;;
esac

## go home, john
cd "$HOME"

## continue loading stuff from .shrc or .bashrc if $rcfile does not match
if [ "${BASH_VERSION:-empty}" = 'empty' ]; then
    [ -e "$HOME/.shrc" ] && source "$HOME/.shrc"
else
    [ -e "$HOME/.bashrc" ] && source "$HOME/.bashrc"
fi

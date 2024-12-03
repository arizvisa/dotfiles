#
# Local-user rc file for bash(1).
#

# if .profile hasn't been executed yet, then do it first.
[ -z "$PROFILE" ] && source "$HOME/.profile"

# set a sane prompt (based on $TERM)
PS1=''
case "$TERM" in
    # putty (xterm)
    xterm*)
        PS1+='\[''\033]2;''\u@\H''\007''\]'                     # set the window title to the user and the full hostname
        PS1+='\[''\033]1;''\u''\007''\]'                        # set the window icon to the user
        PS1+='\[''\033[1;37m''\]''[\!]''\[''\033[0m''\]'' '     # command number in bold white
        PS1+='\[''\033[1;32m''\]''\u@\h''\[''\033[0m''\]'' '    # user@host in bold green
        PS1+='\[''\033[0m''\]''\w\$ '                           # directory and prompt in default
        PS1+='\[''\033K''\]'                                    # clear out everything till the end of line
        ;;

    # tmux and gnu screen
    screen*)
        PS1+='\[''\033]2;''\H''\007''\]'                        # set the window title to the full hostname
        PS1+='\[''\033[1;37m''\]''[\!]''\[''\033[0m''\]'' '     # command number in bold white
        PS1+='\[''\033[1;32m''\]''\u@\h''\[''\033[0m''\]'' '    # user@host in bold green
        PS1+='\[''\033[0m''\]''\w\$ '                           # directory and prompt in default
        PS1+='\[''\033K''\]'                                    # clear out everything till the end of line
        ;;

    # native terminals
    ansi|linux)
        PS1+='\[''\033[1;37m''\]''[\!]''\[''\033[0m''\]'' '     # command number in white
        PS1+='\[''\033[1;32m''\]''\u@\h''\[''\033[0m''\]'' '    # user@host in green
        PS1+='\[''\033[0m''\]''\w\$ '                           # directory and prompt in default
        PS1+='\[''\033K''\]'                                    # clear out everything till the end of line
        ;;

    # unknown
    *)
        PS1='[\!] \u@\h \w\$ '
        ;;
esac
export PS1

# prefix $HOME/bin to PATH
[ -e "$HOME/bin" ] && PATH="$HOME/bin:$PATH"

# set some default options for bash
set -o noclobber
set -o ignoreeof
set -o vi
set -o nounset

shopt -s extglob
shopt -s shift_verbose
[ "${BASH_VERSINFO[0]}" -ge 4 ] && shopt -s globstar

shopt -s failglob
#shopt -s nullglob           # only useful during scripting

# command completion (nope)
shopt -u progcomp
[ "${BASH_VERSINFO[0]}" -ge 5 ] && shopt -u progcomp_alias
complete -r

# command aliases
unalias -a

# modify core utility parameters to improve their safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# remove any distro-specific aliases that have been added for
# some of our core posix utilities, while adding some sane ones.
alias ls &>/dev/null && unalias ls
alias cat &>/dev/null && unalias cat

# some defaults for the common utilities
alias ls='ls -F'
alias cat='cat -v'
alias split="split -d -a3"
alias gawk="gawk -i '$HOME/.gawkrc'"

# sort(1) does not honor record order by default.
alias sort='sort -s'

# aliases for common utilities that add default parameters
case "$platform" in
    msys|cygwin)
        alias ps='command ps -af'
        alias psall='command ps -Waf'
        ;;
    linux*)
        alias ps='command ps -wwlj'
        alias psall='command ps -ewwlj'
        ;;
    freebsd*|darwin*)
        alias ps='command ps -wwl'
        alias psall='command ps -Awwl'
        ;;
    *)

esac

# mappings for external utilities
alias info="`type -P info` --vi-keys"
alias strings="`type -P stringsext || type -P strings`"
alias strace="`type -P strace` -vitttTs 131072"
alias netstat="`type -P netstat` -W"
alias z="`type -P zstd`"
alias clip="`type -P xclip` -sel clip"
alias readelf="readelf -W"

# figure out the pager and default parameters to use
which_pager="`type -P less || type -P more`"
case "${which_pager}" in
    *less) which_pager_args=(-S -i -Q -s) ;;
    *more) which_pager_args=(-d -s) ;;
esac
alias l="${which_pager} ${which_pager_args[*]}"
unset which_pager which_pager_args

# nl(1) is stupid by default, due to not using a proper field separator.
nl()
{
    "`type -P nl`" -w32 -nrn -v0 -ba -s $'\t' "$@" | sed -e $'s/^ *//g' ;
}

# just some shortcuts for viewing the head or tail of a file.
xhead()
{
    local infile='-'
    if [ "$#" -gt 0 ]; then
        infile="$1"
        shift
    fi
    xxd -- "$infile" | head "$@"
}

xtail()
{
    local infile='-'
    if [ "$#" -gt 0 ]; then
        infile="$1"
        shift
    fi
    xxd -- "$infile" | tail "$@"
}

# bash's time(1) is stupid by default, due to not emitting any resource usage.
alias time="`type -P time` --verbose"

# journalctl(1) is 100% written by fucking idiots.
alias jdate='date +"%Y-%m-%d %H:%M:%S"'

## platform-specific fixes
case "$platform" in
    darwin)
        readlink() { greadlink "$@"; }
        export -f readlink
    ;;

    linux-gnu)
        alias tar='tar --force-local'
        alias ip='ip -color=never'      # system tools using colors by default is pretty fucking stupid.
        alias pstree="pstree -cagplt"

        # make pkill(1) not silent, and pgrep(1) not ma
        alias pgrep='pgrep -a'
        alias pkill='pkill -e'

        # XXX: Xsession and xinitrc (via xinitrc-common) on linux is pretty stupid,
        #      so we need to disable nounset if we are being executed from it.
        let last="-1 + ${#BASH_SOURCE[@]}"
        script=`basename "${BASH_SOURCE[$last]}"`
        if [ "$script" == 'Xsession' ] || [ "$script" == 'xinitrc' ]; then
            set +o nounset
        fi
        unset last script
    ;;

    freebsd*)
        alias pgrep='pgrep -l'
        alias pgrep='pkill -l'
    ;;
esac

# posix
if [ "$os" == "posix" ]; then
    # disable google-chrome's automatic synchronization of google account information
    chrome_config="$HOME/.config/google-chrome"
    if [ -e "$chrome_config/Default/Preferences" ] && type -P jq >/dev/null; then
        chrome_prefs="$chrome_config/Default/Preferences"
        case `jq '.SyncDisabled' "$chrome_prefs"` in
            true) ;;
            null|false)
                echo "$0 : Fixing Google Chrome's policies ($chrome_prefs) to disable automatic sychronization of account information." 1>&2
                jq -c '.SyncDisabled=true' "$chrome_prefs" >| "$chrome_prefs-"
                mv -f "$chrome_prefs-" "$chrome_prefs"
                ;;
            *)
                echo "$0 : Refusing to modify Google Chrome's policies ($chrome_prefs) due to unexpected value specified for \"SyncDisabled\"." 1>&2
                ;;
        esac
        unset chrome_prefs
    fi
    unset chrome_config
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
    infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read TI; do
        description=`man -w 5 terminfo | xargs zcat | grep -A 5 -e "\b$TI[^[:print:]]" | grep -ve '^\.' | tr -d '\n' | sed 's/T{/{/g;s/T}/}/g' | grep -m1 -o -e '{[^\}]\+}\?' | tr -d '\n'`
        if [ -z "$description" ]; then
            printf "%s\n" "$TI"
        else
            printf "%s -- %s\n" "$TI" "$description"
        fi
    done
}

__typecscope()
{
    path="$1"

    descriptions=("cscope" "global")
    databases=("cscope.out" "GTAGS:GPATH:GRTAGS")
    for index in `seq ${#descriptions[*]}`; do
        i=$(( $index - 1 ))
        description="${descriptions[$i]}"

        local -a filenames
        IFS=: read -a filenames <<< "${databases[$i]}"

        local -i count=0
        for filename in "${filenames[@]}"; do
            [ -f "$path"/"$filename" ] && count="$count + 1"
        done

        if [ "${#filenames[@]}" == "$count" ]; then
            echo "$path/${filenames[0]}"$'\t'"$description"
            return `true`
        fi

        unset -v count filenames
    done
    return `false`
}

__addcscope()
{
    local listsep
    [ "${os}" = "windows" ] && listsep=";" || listsep=":"

    [ "$#" -eq "0" ] && path="`pwd`" || path="$@"
    local current_db p
    current_db="${CSCOPE_DB:-}"
    for p in $path; do
        local fp
        if [ -d "$p" ]; then
            read filename description < <( __typecscope "$p" )
            if (( "$?" > 0 )); then
                echo -n 'Unable to locate a tags database: '"$p"$'\n' 1>&2
                continue
            fi

            echo -n 'Found a '"$description"' database: '"$filename"$'\n'
            rp="$filename"

        elif [ -f "$p" ]; then
            filename=`basename "$p"`
            ext="${filename##*.}"
            case "$filename" in
            cscope.out)
                echo -n 'Found a cscope database: '"$filename"$'\n'
                ;;
            GTAGS|GPATH|GRTAGS)
                echo -n 'Found a global database: '"$filename"$'\n'
                ;;
            *)
                echo -n 'Unknown database type specified by user: '"$filename"$'\n'
            esac
            rp="$filename"

        fi

        [ "${os}" = "windows" ] && ap=`cygpath -w "$rp"` || ap=`cygpath "$rp"`
        echo -n 'Adding path to CSCOPE_DB: '"$ap"$'\n' 1>&2
        [ "$current_db" = "" ] && current_db="$ap" || current_db="$current_db""${listsep}""$ap"
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
    for nn in `tr "${listsep}" "\n" <<< "${CSCOPE_DB:-}"`; do
        local n
        [ "${os}" = "windows" ] && n=`cygpath "$nn"` || n="$nn"

        if [ ! -e "$n" ]; then
            echo -n 'Removing missing database from CSCOPE_DB: '"$n"$'\n' 1>&2
            continue
        fi

        found=0
        for np in $cull; do
            local p
            [ "${os}" = "windows" ] && p=`cygpath "$np"` || p="$np"

            if [ -d "$p" ]; then
                read filename description < <( __typecscope "$p" )
                (( "$?" > 0 )) && continue
                p="${filename}"
            fi

            [ "${os}" = "windows" ] && nabs=`cygpath -w "$n"` || nabs=`cygpath "$n"`
            [ "${os}" = "windows" ] && pabs=`cygpath -w "$p"` || pabs=`cygpath "$p"`

            if [ "$nabs" == "$pabs" ]; then
                found=`expr "$found" + 1`
            fi
        done

        if [ "$found" -gt 0 ]; then
            echo -n 'Removing database from CSCOPE_DB: '"$n"$'\n' 1>&2
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

#
# Local-user rc file for bash(1).
#

# if .profile hasn't been executed yet, then do it first.
[ -z "$PROFILE" ] && source "$HOME/.profile"

# set a sane prompt (based on $TERM)
PS1=''
case "$TERM" in
    # putty
    xterm*)
        PS1+='\[\033]0;\u@\H\007\]'                 # set the window title to the user and the full hostname
        PS1+='\[\033[01;37m\][\!]\[\033[0m\] '      # command number in white
        PS1+='\[\033[01;32m\]\u@\h\[\033[0m\] '     # user@host in green
        PS1+='\[\033[0m\]\w\$ '                     # directory and prompt in default
        PS1+='\[\033K\]'                            # clear out everything till the end of line
        ;;

    # tmux and gnu screen
    screen*)
        PS1+='\[\033]0;\H\007\]'                    # set the window title to the full hostname
        PS1+='\[\033[01;37m\][\!]\[\033[0m\] '      # command number in white
        PS1+='\[\033[01;32m\]\u@\h\[\033[0m\] '     # user@host in green
        PS1+='\[\033[0m\]\w\$ '                     # directory and prompt in default
        PS1+='\[\033K\]'                            # clear out everything till the end of line
        ;;

    # native terminals
    ansi|linux)
        PS1+='\[\033[01;37m\][\!]\[\033[0m\] '      # command number in white
        PS1+='\[\033[01;32m\]\u@\h\[\033[0m\] '     # user@host in green
        PS1+='\[\033[0m\]\w\$ '                     # directory and prompt in default
        PS1+='\[\033K\]'                            # clear out everything till the end of line
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

## aliases and complete
unalias -a
complete -r

# modify core utility parameters to improve their safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias cat='cat -v'

# remapping of common utilities
alias info="`type -P info` --vi-keys"
alias strings="`type -P stringsext || type -P strings`"
alias strace="`type -P strace` -vitttTs 131072"
alias netstat="`type -P netstat` -W"
alias z="`type -P zstd`"

which_pager="`type -P less || type -P more`"
case "${which_pager}" in
    *less) which_pager_args=(-S -i -Q -s) ;;
    *more) which_pager_args=(-d -s) ;;
esac
alias l="${which_pager} ${which_pager_args[*]}"
unset which_pager which_pager_args

# some defaults for the common utilities
alias ls='ls -F'

# sort(1) does not honor record order by default.
alias sort='sort -s'

# nl(1) is stupid by default, due to not using a proper field separator.
nl()
{
    "`type -P nl`" -w32 -nrn -v0 -ba -s $'\t' "$@" | sed -e $'s/^ *//g' ;
}

# bash's time(1) is stupid by default, due to not emitting any resource usage.
alias time="`type -P time` --verbose"

# remove any distro-specific aliases that have been added for
# some of our core posix utilities, while adding some sane ones.
alias ls &>/dev/null && unalias ls
alias cat &>/dev/null && unalias cat

# journalctl(1) is 100% written by fucking idiots.
alias jdate='date +"%Y-%m-%d %H:%M:%S"'

# aliases for common utilities that add default parameters
alias readelf="readelf -W"
alias pstree="pstree -cagplt"
case "$platform" in
    msys|cygwin)    alias ps='ps -af'       ;;
    *)              alias ps="ps -ww -lj"   ;;
esac

## platform-specific fixes
# darwin
if [ "$platform" == "Darwin" ]; then
    readlink() { greadlink "$@"; }
    export -f readlink
fi

if [ "$platform" == "linux-gnu" ]; then
    alias tar='tar --force-local'
fi

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
     infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read n; do printf "%s -- %s\n" "$n" "`man -w 5 terminfo | xargs zcat | egrep -A 2 \"\b$n[^[:print:]]\" | tr -d '\n' | sed 's/T{/{/g;s/T}/}/g' | egrep -m1 -o '\{[^}]+\}' | tr -d '\n'`"; done
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
    current_db="$CSCOPE_DB"
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
        echo 'Adding path to CSCOPE_DB: '"$ap"$'\n' 1>&2
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
    for nn in `echo "$CSCOPE_DB" | tr "${listsep}" "\n"`; do
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

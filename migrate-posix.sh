#!/bin/sh
path=`dirname "$0"`
if test "$#" -ne 1; then
    printf "Usage: %s target\n" "$0" 1>&2
    printf "Symbolically links the contents of %s into the directory specified by target.\n" "$path/posix" 1>&2
    exit 1
fi
fullpath=`readlink -f "$path"`

## check if os is defined
case "$os" in
windows|posix)
    ;;
*)
    printf 'Environment variable "%s" is not defined. Attempting to determine operating system..\n' "os" 1>&2

    # we can cheat when detecting the os because Windows defines a variable "OS"
    case "$OS" in
    Windows*) os="windows" ;;
    *) os="posix" ;;
    esac
    printf 'Determined operating system: %s\n' "$os" 1>&2
    ;;
esac

## check that the argument is a directory
if [ ! -d "$1" ]; then
    printf "Target path is not a directory: %s\n" "$1" 1>&2
    exit 1
fi

## method for linking a directory
link_directory()
{
    name="$1"
    source="$2"
    destination="$3"

    if [ -e "$destination/$name" ] && [ ! -d "$destination/$name" ]; then
        printf "%s: Destination file exists and is not a directory: %s\n" "$name" "$destination/$name" 1>&2
        return 1
    fi

    case "$os" in
    windows)
        tar -cpf- -C "$source" "$name" | tar -xpf- --overwrite -C "$destination"
        ;;
    posix)
        ln -snf "$source/$name" "$destination/$name"
        ;;
    *)
        printf "%s: Unable to link directory into \"%s\".\n" "$name" "$destination" 1>&2
        return 1
        ;;
    esac

    return $?
}

## method for linking a file
link_file()
{
    name="$1"
    source="$2"
    destination="$3"

    if [ -e "$destination/$name" ] && [ ! -f "$destination/$name" ]; then
        printf "%s: Destination file exists and is not a file: %s\n" "$name" "$destination/$name" 1>&2
        return 1
    fi

    case "$os" in
    windows)
        ln -sf "$source/$name" "$destination/$name"
        ;;
    posix)
        ln -snf "$source/$name" "$destination/$name"
        ;;
    *)
        printf "%s: Unable to link file into \"%s\".\n" "$name" "$destination" 1>&2
        return 1
        ;;
    esac

    return $?
}

## method for linking symbolically
link_symbolic()
{
    name="$1"
    source="$2"
    destination="$3"

    if [ -e "$destination/$name" ] && [ ! -L "$destination/$name" ]; then
        printf "%s: Destination file exists and is not a symbolic link: %s\n" "$name" "$destination/$name" 1>&2
        return 1
    fi

    case "$os" in
    windows)
        printf "%s: Symbolic links not supported on windows.\n" "$name" 1>&2
        ;;
    posix)
        ln -snf "$source/$name" "$destination/$name"
        ;;
    *)
        printf "%s: Unable to link name into \"%s\".\n" "$name" "$destination" 1>&2
        return 1
        ;;
    esac
}

## process everything in ./posix
find "$fullpath/posix" -mindepth 1 -maxdepth 1 -print | while read path; do
    name=`basename "$path"`
    if [ -d "$fullpath/posix/$name" ]; then
        link_directory "$name" "$fullpath/posix" "$1"
    elif [ -e "$fullpath/posix/$name" ] && ([ -f "$1/$name" ] || [ ! -e "$1/$name" ]); then
        link_file "$name" "$fullpath/posix" "$1"
    elif [ -L "$fullpath/posix/$name" ]; then
        link_symbolic "$name" "$fullpath/$posix" "$1"
    else
        printf "Unable to link unknown file type: %s\n" "$fullpath/posix/$name" 1>&2
    fi
done

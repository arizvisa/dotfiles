#!/bin/sh
path=`dirname "$0"`
if test "$#" -ne 1; then
    printf "Usage: %s target\n" "$0" 1>&2
    printf "Symbolically links the contents of %s into the directory specified by target.\n" "$path/posix" 1>&2
    exit 1
fi
fullpath=`readlink -f "$path"`

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

    case "$os" in
    windows)
        printf "%s: tar -cpf- -C \"%s\" \"%s\" | tar -xpf- -C \"%s\"\n" "$name" "$source" "$name" "$destination" 1>&2
        tar -cpf- -C "$source" "$name" | tar -xpf- -C "$destination" 
        ;;
    posix)
        printf "%s: ln -snf \"%s\" \"%s\"\n" "$name" "$source/$name" "$destination/$name" 1>&2
        ln -snf "$source/$name" "$destination/$name"
        ;;
    *)
        printf "%s: Unable to link directory into \"%s\".\n" "$name" "$destination" 1>&2
        ;;
    esac
}

## method for linking a file
link_file()
{
    name="$1"
    source="$2"
    destination="$3"

    case "$os" in
    windows)
        printf "%s: ln -sf \"%s\" \"%s\"\n" "$name" "$source/$name" "$destination/$name" 1>&2
        ln -sf "$source/$name" "$destination/$name"
        ;;
    posix)
        printf "%s: ln -snf \"%s\" \"%s\"\n" "$name" "$source/$name" "$destination/$name" 1>&2
        ln -snf "$source/$name" "$destination/$name"
        ;;
    *)
        printf "%s: Unable to link file into \"%s\".\n" "$name" "$destination" 1>&2
        ;;
    esac
}

## process everything in ./posix
find "$fullpath/posix" -mindepth 1 -maxdepth 1 -print | while read path; do
    name=`basename "$path"`
    if [ -d "$1/$name" ]; then
        link_directory "$name" "$fullpath/posix" "$1"
    elif [ -e "$1/$name" ] && [ -f "$1/$name" ]; then
        link_file "$name" "$fullpath/posix" "$1"
    else
        printf "Unable to link unknown file type: %s\n" "$path" 1>&2
    fi
done

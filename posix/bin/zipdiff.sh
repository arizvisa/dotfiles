#!/bin/sh

## constants
progname=$0
HASHMETHOD=md4
diffContents=0

## functions
function reencode()
{
    filename="$1"
    targetencoding="$2"
    sourceencoding=`file -bi "$filename" | grep -e "charset=[^;]\+$" | cut -d= -f2`
    iconv -s -c -f "$sourceencoding" -t "$targetencoding" "$filename" 2>/dev/null || return 1
    return 0
}

## check file arguments
if test "$1" == "-d"; then
    diffContents=1
    shift 1
fi

if test "$#" -ne 2; then
    echo "Usage: $0 [-d] original-file modified-file"
    exit 1
fi

original="$1"
modified="$2"

## check mime types
original_mime=`file -b --mime-type "$original"`
modified_mime=`file -b --mime-type "$modified"`

if test "$original_mime" != "application/zip" -a "$original_mime" != "application/octet-stream"; then
    echo "file \"$original\" is of incorrect mime type : \"$original_mime\"" 1>&2
    exit 1
fi
if test "$modified_mime" != "application/zip" -a "$modified_mime" != "application/octet-stream"; then
    echo "file \"$modified\" is of incorrect mime type : \"$modified_mime\"" 1>&2
    exit 1
fi
unset original_mime modified_mime

## extract contents of both zips
if test ! -d "$TMP"; then
    echo "\$TMP variable does not point to a valid directory : $TMP" 1>&2
    exit 1
fi

directory_base="$TMP/zipdiff.$$"
original_name=`basename "$original"`
modified_name=`basename "$modified"`

mkdir -p "$directory_base.$original_name"
mkdir -p "$directory_base.$modified_name"
trap "rm -rf '$directory_base.$original_name' '$directory_base.$modified_name'" INT TERM EXIT

unzip -qq "$original" -d "$directory_base.$original_name"
unzip -qq "$modified" -d "$directory_base.$modified_name"

printf ': Figuring out the difference between : %s : %s\n' "$original" "$modified"

## Show directories that have been added or removed
( cd "$directory_base.$original_name" && find ./ -type d | sort >| "$TMP/zipdiff.$$.original" )
( cd "$directory_base.$modified_name" && find ./ -type d | sort >| "$TMP/zipdiff.$$.modified" )

printf ': Directories that have been added/removed:\n'
output=`diff -u "$TMP/zipdiff.$$.original" "$TMP/zipdiff.$$.modified" | grep -e '^[+-][^+-]'`
if test "$output" != ""; then
    echo "$output"
fi
printf '\n'

## Show files that have been added/removed
( cd "$directory_base.$original_name" && find ./ -type f | sort >| "$TMP/zipdiff.$$.original" )
( cd "$directory_base.$modified_name" && find ./ -type f | sort >| "$TMP/zipdiff.$$.modified" )
trap "rm -f '$TMP/zipdiff.$$.original' '$TMP/zipdiff.$$.modified'" INT TERM EXIT

printf ': Files that have been added/removed:\n'
output=`diff -u "$TMP/zipdiff.$$.original" "$TMP/zipdiff.$$.modified" | grep -e '^[+-][^+-]'`
if test "$output" != ""; then
    echo "$output"
fi
printf '\n'

## Show files that have differing contents
printf ': Files contents that have changed:\n'
(
cd "$directory_base.$original_name" && find ./ -type f | while read p; do
    orgfile="$directory_base.$original_name/$p"
    modfile="$directory_base.$modified_name/$p"
    test ! -e "$modfile" && continue

    isDifferent=0

    # first fingerprints
    if test "$isDifferent" -eq 0; then
        fp_org=`file -b "$orgfile"`
        fp_mod=`file -b "$modfile"`
        if test "$fp_org" != "$fp_mod"; then
            printf '%s : different fingerprints : %s : %s\n' "$p" "$fp_org" "$fp_mod"
            isDifferent=1
        fi
    fi

    # next checksum
    if test "$isDifferent" -eq 0; then
        cv_orig=`openssl dgst -r -$HASHMETHOD "$orgfile" 2>/dev/null | cut -d' ' -f1`
        cv_mod=`openssl dgst -r -$HASHMETHOD "$modfile" 2>/dev/null | cut -d' ' -f1`
        if test "$cv_orig" != "$cv_mod"; then
            printf '%s : different checksums : %s : %s\n' "$p" "$cv_orig" "$cv_mod"
            isDifferent=1
        fi
    fi

    test "$diffContents" -eq "0" && continue

    # skip file if they are not different
    test "$isDifferent" -eq "0" && continue

    # diffing ascii file contents
    isOrgText=`echo "$fp_org" | egrep -oi "text|script" 1>/dev/null && echo 1 || echo 0`
    isModText=`echo "$fp_mod" | egrep -oi "text|script" 1>/dev/null && echo 1 || echo 0`
    if test "$isOrgText" -gt "0" -o "$isModText" -gt "0"; then
        # converting encoding of both files to ascii
        result=0
        reencode "$orgfile" "us-ascii" 2>/dev/null >| "$orgfile.normalized"
        result=`expr "$result" + $?`
        reencode "$modfile" "us-ascii" 2>/dev/null >| "$modfile.normalized" || cat "$modfile" >| "$modfile.normalized"
        result=`expr "$result" + $?`
    else
        # converting to a hexdump
        xxd "$orgfile" >| "$orgfile.normalized"
        xxd "$modfile" >| "$modfile.normalized"
    fi

    diff -y "$orgfile.normalized" "$modfile.normalized"
    printf '\n\n'
done
)

printf '\n'

## Clean up temp directories and files
rm -f "$TMP/zipdiff.$$.{original,modified}"
rm -rf "$directory_base.{$original_name,$modified_name}"

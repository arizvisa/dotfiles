#!/bin/sh
baseurl="$1"
depth=5         # default recursion depth

if [ $# -ne 1 ]; then
    printf "Usage: %s baseurl\n" "$0"
    printf "Uses wget(1) to mirror the contents of a url to the current directory.\n"
    exit 1
fi

## read the components and remove the protocol if one exists
## this way we can count them.
IFS=/ read -a components <<< "$baseurl"
set -- "${components[@]}"
while [ $# -gt 0 ]; do
    [ "$1" == "" ] && break
    shift
done

## if we have some elements leftover, then we need to shift
## out any empty strings that it begins with.
if [ $# -gt 0 ]; then
    while [ "$1" == "" ]; do
        shift
    done

    ## next we need to shift out the host directory in order
    ## to get the number of components that we need to cut
    ## out while mirroring our url.
    shift
    count="$#"

## otherwise there was no protocol and we need to assume the
## first parameter is the hostname that we need to exclude.
else
    set -- "${components[@]}"
    shift
    count="$#"
fi

## now we can build our wget commandline to mirror this thing.
url="$baseurl"
directory_prefix_count="$count"
exec wget --timestamping --no-host-directories --adjust-extension --page-requisites --convert-links "--cut-dirs=$directory_prefix_count" --recursive "--level=$depth" "$url"
#wget -N -k -p -E -nH -r -l $depth

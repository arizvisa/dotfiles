#!/usr/bin/env bash
interface=wlp2s0
args=( -e -l --number --print -v -XX )

if [ "$#" -lt 1 ]; then
        echo "Usage: $0 filename" 1>&2
        exit 22
fi

outfile=$1
shift
echo "Capturing from interface ${interface} to ${outfile}" 1>&2

tcpdump -n -i "${interface}" -s 0 "${args[@]}" -w "${outfile}" "$@" 

#!/bin/sh
url=https://dogbolt.org/api/binaries/
sleeper=5
foo=22
bar=132 # for snowman

exec < <(cat <<EOF
angr
Hex-Rays
Snowman
BinaryNinja
Boomerang
Ghidra
RecStudio
Reko
RetDec
EOF
)

read -d'\0' available
exec <&-
read formatted < <(xargs printf ' [%s]' <<<"$available")
[ "$#" -le 1 ] && printf 'Usage: %s filename %s\n' "$0" "$formatted" 1>&2 && exit 1

Ffilter()
{
    printf -- '-e ^%s\0' "$@" | xargs -0 echo grep -c
}

logger()
{
    printf "$@" 1>&2
}

check()
{
    read url < <( printf '%s?%s\n' "$1" 'completed=true')
    shift
    filter=`Ffilter "$@"`

    outfile=`mktemp`
    while curl -o "$outfile" "$url"; do
        read count < <(jq -r '.results[].decompiler.name' "$outfile" | $filter)
        logger 'Got %d requirements out of %d: %s\n' "$count" "$#" "$*"
        [ "$count" -ge "$#" ] && break
        logger 'Sleeping for %d seconds...\n' "$sleeper"
        sleep "$sleeper"
        logger 'Hitting up: %s\n' "$url"
    done
    jq -r '.count,(.results[] | [select(.error | not)] | map([.id, ([.decompiler.name, .decompiler.version + if (.decompiler.revision | length) > 0 then (" ("+.decompiler.revision+")") else "" end] | join(" ")), .analysis_time, .download_url]) | flatten[])' "$outfile"
    #jq -r '.count,(.results[] | [select(.error | not)] | map([.id, .decompiler.name + " " + if .decompiler.revision then .decompiler.version + "(" + .decompiler.revision + ")" else decompiler.version end, .analysis_time, .download_url]) | flatten[])' "$outfile"
    rm -f "$outfile"
}

process()
{
    index=0
    while [ "$index" -lt "$count" ]; do
        IFS=$'\n' read name url
        printf ">>>>> '%s' '%s'\n" "$name" "$url"
        index=`expr "$index" + 1`
    done
}

barrier()
{
    prefix="$1"
    width="$2"
    shift 2
    test "$#" -gt 0 && corner="$1" || corner='+'
    test "$#" -gt 1 && horizontal="$2" || horizontal='-'
    awk -v "horz=$horizontal" -v "corn=$corner" -v "prefix=$prefix" -v "width=$width" 'function rep(count, char, agg) { while (0 < count--) { agg = agg char } return agg } BEGIN { prefixlen = prefix - length(corn) } { print corn rep(prefixlen, horz) $0 rep(width - length($0) - prefixlen, horz) corn }'
}

printf '%s\n' "$@" | nl | sed 1d | while read index item; do grep -qe "^$item$" <<<"$available" && continue || printf 'Error: parameter %d: unknown decompiler %s\n' "$index" "$item" && exit 1; done || exit 1
dd 2>/dev/null ibs=1 if="$1" | grep -qU $'\x7FELF' || (printf 'Error: %s needs an ELF as its first parameter\n' "$0" && exit 1) || exit 1

read -d '\n' id download decompilation < <(curl -F "file=@$1" "$url" | jq -r '.id, .download_url, .decompilations_url')
shift
check "$decompilation" "$@" | (
    IFS=$'\n' read count
    paste -d '\t' - - - - | head -n "$count"
) | while IFS=$'\t' read id name time url; do
    printf ' |start| %s: %fs \n' "$name" "$time" | barrier "$foo" "$bar" / \*
    curl "$url"
    printf ' |stop| %s: %fs \n' "$name" "$time" | barrier "$foo" "$bar" / \*
done

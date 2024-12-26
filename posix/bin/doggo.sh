#!/usr/bin/env bash
url=https://dogbolt.org/api/binaries/
sleeper=5
foo=22
bar=132 # for snowman

filter_html_contents()
{
    xmlstarlet format --html --recover 2>/dev/null | xmlstarlet sel -t -v "//*[@id=\"$1\"]"
}

baseurl=`cut -d/ -f1-3 <<<"$url"`
read -d'\0' available < <( <<<"$url" cut -d/ -f1-3 | xargs curl | filter_html_contents decompilers_json | jq -r 'keys | reverse[]')
read formatted < <(xargs printf ' [%s]' <<<"$available")
[ "$#" -lt 1 ] && printf 'Usage: %s filename %s\n' "$0" "$formatted" 1>&2 && exit 1

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

checkelf()
{
    dd 2>/dev/null ibs=1 count=4 if="$1" | grep -qU -e $'\x7FELF'
}

checkmz()
{
    dd 2>/dev/null ibs=1 count=2 if="$1" | grep -qU -e 'MZ' -e 'ZM'
}

checkpe()
{
    if checkmz "$1"; then
        read e_lfanew < <(dd 2>/dev/null ibs=1 count=4 skip=60 if="$1" | od --endian=little -An -w4 -td4)
        dd 2>/dev/null ibs=1 count=4 skip="$e_lfanew" if="$1" | grep -qU -e $'PE\0\0'
    else
        false
    fi
}

checksig()
{
    checkelf "$1" && return
    checkmz "$1" && checkpe "$1" && return
    checkmz "$1" && return
    false
}

printf '%s\n' "$@" | nl | sed 1d | while read index item; do grep -qe "^$item$" <<<"$available" && continue || printf 'Error: parameter %d: unknown decompiler %s\n' "$index" "$item" && exit 1; done || exit 1
checksig "$1" || (printf 'Error: %s needs an ELF, MZ/PECOFF, or MZ as its first parameter\n' "$0" && exit 1) || exit 1

read -d '\n' id download decompilation < <(curl -F "file=@$1" "$url" | jq -r '.id, .download_url, .decompilations_url')
shift

[ "$#" -eq 0 ] && set -- $available

check "$decompilation" "$@" | (
    IFS=$'\n' read count
    paste -d '\t' - - - - | head -n "$count"
) | while IFS=$'\t' read id name time url; do
    printf ' |start| %s: %fs \n' "$name" "$time" | barrier "$foo" "$bar" / \*
    curl "$url"
    printf ' |stop| %s: %fs \n' "$name" "$time" | barrier "$foo" "$bar" / \*
done

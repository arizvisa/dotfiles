#!/bin/sh

logerror()
{
        echo "Error: $*" 1>&2
}
log()
{
        [ $flag_silent -eq 0 ] && echo "[*]" "$*" 1>&2
}
logverbose()
{
        [ $flag_silent -eq 0 ] && [ $flag_verbose -eq 1 ] && echo "[" $(date -n) "]" "$*" 1>&2
}

halp()
{
    argv0=$1
    cat 1>&2 <<EOF
Usage: $argv0 TSLyyyymmdd-xx|record-id
Description: Fetch archive from Telus Portal ( http://google.com/search?q=site:http://telussecuritylabs.com/threats/show/# )
Options:
  -h,--help    Display this information
  -v           Be very very verbose
  -q           Be very very quiet..

Environment:
    SESSION     _subscriber_session
    USER_AGENT  user agent
EOF
}

curl_get()
{
    url=$1
    referrer=$2
    shift 2

    cookie="_subscriber_session=$SESSION"
    host="portal.telussecuritylabs.com"
    curl "$url" -f -s -k --compressed -H "Accept-Encoding: gzip,deflate,sdch" -H "Host: $host" -H "Accept-Language: en-US,en;q=0.8" -H "User-Agent: $USER_AGENT" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Cookie: $cookie" -H "Referer: $referer" $@
}

tidy_up()
{
    tidy -xml -q --show-errors 0 --show-warnings n --indent y --indent-spaces 2 --doctype omit --show-body-only y --clean y --join-classes y --join-styles y --punctuation-wrap y --enclose-text y --enclose-block-text y --break-before-br y --wrap 0 2>/dev/null
}

fetch_recordid()
{
    tslid=$1
    shift

    url="https://portal.telussecuritylabs.com/threat/$tslid"
    referer="http://telussecuritylabs.com/threats/show/"

    html=$( curl_get $url $referer $@ )
    recordid=$( echo "$html" | xml-select a class list_nav | xml-tagger a href | grep -e '^/archive/confirm_download_threat/' )
    basename "$recordid"
}

### FIXME: get the telus threatid from a record number
fetch_threatid()
{
    recordid=$1
    shift

    url="https://portal.telussecuritylabs.com/archive/confirm_download_threat/$recordid"
}

fetch_summary()
{
    tslid=$1
    shift

    url="https://portal.telussecuritylabs.com/threat/$tslid"
    referer="http://telussecuritylabs.com/threats/show/"

    html=$( curl_get $url $referer $@ )
    echo "$html" | egrep 'TSL[0-9]{8}' | xml-select div | xml-select h3 | head -n 1 | xml-strip | sed 's/^ *//;s/ *$//;s/ /:/'
}

generate_assets()
{
    id=$1
    html=$2

    cat "$html" | xml-select input name threat[$id][] | xml-tagger input name >| .$$.names
    cat "$html" | xml-select input name threat[$id][] | xml-tagger input value >| .$$.values
    paste .$$.names .$$.values | while read a b; do echo "$a=$b"; done | sed ':a;N;$!ba;s/\n/\&/g'
    rm -f .$$.names .$$.values
}

request_id()
{
    id=$1
    shift

    referer="https://portal.telussecuritylabs.com"
    curl_get "https://portal.telussecuritylabs.com/archive/confirm_download_threat/$id" $referer $@
}

request_threat()
{
    tslid=$1
    shift

    url="https://portal.telussecuritylabs.com/threat/$tslid"
    referer="http://telussecuritylabs.com/threats/show/"

    curl_get $url $referer $@ | xml-path '//table[@id="container"]//td[@id="right_content"]'
}

request_assets()
{
    id=$1
    html=$2
    shift 2

    data=$(generate_assets "$id" "$html")

    referer="https://portal.telussecuritylabs.com/archive/confirm_download_threat/$id"
    curl_get "https://portal.telussecuritylabs.com/archive/download_threat" "$referer" --data "$data" $@
}

argv0=$0
args=$( getopt qvh $* )
if [ "$?" -ne 0 -o "$#" -eq 0 ]; then
    logerror "Need an id number to download"
    halp "$argv0"
    exit 1
fi

flag_silent=0
flag_verbose=0

set -- $args
while [ $# -gt 0 ]; do
    case "$1" in 
        -h) halp $argv0; exit 0 ;;
        -q) flag_silent=1; shift ;;
        -v) flag_verbose=1; shift ;;
        --) shift; break ;;
    esac
done

if test "$USER_AGENT" == ""; then
    USER_AGENT="Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.95 Safari/537.36"
fi

if test "$SESSION" == ""; then
    logerror "Need the SESSION environment variable set"
    halp "$argv0"
    exit 1
fi

if echo "$SESSION" | egrep -v '^[0-9a-f]{32}' >/dev/null; then
    logerror "SESSION variable is not of the correct format. Should be a 256-bit hex number."
    halp "$argv0"
    exit 1    
fi

telus_id=$1
if echo "$telus_id" | egrep '^[0-9]+$' >/dev/null; then 
    summary="https://portal.telussecuritylabs.com/archive/confirm_download_threat/$telus_id"
    id="$telus_id"
    filename="$id"  # XXX

    logverbose "Determining telus-id from record $id..."
    telus_id=$(fetch_threatid "$telus_id")
else
    logverbose "Determining summary and record information from telus-id $telus_id..."
    summary=$(fetch_summary "$telus_id")
    id=$(fetch_recordid "$telus_id")
    filename=$(echo $summary | cut -d ':' -f 1)
fi

if test "$filename" == ""; then
    logerror "Unable to determine filename to write to. Failure to authenticate with SESSION hash?"
    exit 1
fi

logverbose "Saving threat information to $filename.html | $summary"
request_threat "$telus_id" | tidy_up >| "$filename.html"

if test "$id" == ""; then
    log "$telus_id::$summary"
    logerror "Unable to determine the recordid for $telus_id. Perhaps there's no assets to download?"
    exit 1
fi

logverbose "Creating $filename.zip for record number $id"
request_id $id >| .$$.assets
request_assets $id .$$.assets -o "$filename.zip"
rm -f .$$.assets

log "$telus_id:$filename.zip:$summary"

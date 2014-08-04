#!/bin/sh

logerror()
{
        echo "Error: $*" 1>&2
}
log()
{
        [ $flag_silent -eq 0 ] && echo "Status: $*" 1>&2
}
logverbose()
{
        [ $flag_silent -eq 0 ] && [ $flag_verbose -eq 1 ] && echo "Status: $*" 1>&2
}

halp()
{
    argv0=$1
    cat 1>&2 <<EOF
Usage: $argv0 username subscriber password
Description: Authenticate to Telus Portal ( http://google.com/search?q=site:http://telussecuritylabs.com/threats/show/# )
Options:
  -h,--help    Display this information

Examples:
    USERNAME -- javery
    SUBSCRIBER -- 8675-0000
    PASSWORD -- @8%-BuR*3Yzp
EOF
}

curl_post()
{
    url=$1
    data=$2
    referer=$3
    shift 3

    host="portal.telussecuritylabs.com"
    session=$( curl "$url" -f -s -k --compressed -d "$data" -D - -o /dev/null -H "Host: $host" -H "Referer: $url" -H "Accept-Language: en-US,en;q=0.8" -H "User-Agent: $agent" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: $referer" $@ )

    if test "$session" == ""; then
        return 1
    fi
    echo "$session"
    return 0
}

authenticate()
{
    username=$1
    subscriber=$2
    password=$3

    url="https://portal.telussecuritylabs.com/home/authenticate"
    referer="https://portal.telussecuritylabs.com/"
    data="user[username]=$username&user[subscriber_number]=$subscriber&user[password]=$password"

    curl_post $url "$data" $referer | egrep '^Set-Cookie: ' | cut -d ':' -f 2- | tr ';' '\n' | grep '_subscriber_session' | cut -d '=' -f 2
}

argv0=$0
args=$( getopt h $* )
if [ "$?" -ne 0 -o "$#" -ne 3 ]; then
        echo "Need username, subscriber, and password" 1>&2
        halp "$argv0"
        exit 1
fi

flag_silent=0
flag_verbose=0

set -- $args
while [ $# -gt 0 ]; do
    case "$1" in 
        -h) halp $argv0; exit 0 ;;
        --) shift; break ;;
    esac
done

u=$1
s=$2
p=$3

SESSION=$(authenticate $u $s $p)

if test "$?" == 0; then
    echo "Authenticated with _subscriber_session=$SESSION" 1>&2
else
    echo "Authentication failed" 1>&2
    exit 1
fi

export SESSION

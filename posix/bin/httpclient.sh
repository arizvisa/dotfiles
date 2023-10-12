#!/usr/bin/env bash
# Author: see http://bashcurescancer.com/improve-this-script-win-100-dollars.htm l
# Improve and send to me

## improved by siflus on Wed Sep  5 16:30:31 EDT 2007
## added support for chunked encoding
## returns 1 on failure

TIMEOUT=30
USERAGENT="Mozilla/5.0"

### error the fuck out of here
function error()
{
    echo "$*"
    exit 1
}

### primitive for a really fake associative array in bash
function getItem()
{
    field=$1
    shift

    for item in "$@"; do
        # FIXME: check that $item doesn't contain any invalid characters
        key=$( echo "$item" | cut -d ':' -f 1 )
        value=$( echo "$item" | cut -d ':' -f 2- )
        if [ "$key" == "$field" ]; then
            read trimmed <<< "$value"
            echo "$value"
            return
        fi
    done
}

function hex2int()
{
    # FIXME: make sure num is actually a hex number
    num=$(echo $1 | tr 'abcdef' 'ABCDEF')
    echo "ibase=16; $num" | bc
}

### make an HTTP request
function httpRequest()
{
    HOST=$1
    PORT=$2
    METHOD=$3   # we really only care about GET
    RESOURCE=$4

    ## connect with a bash flavor
    exec 3<> /dev/tcp/$HOST/$PORT
    if [ $? -ne 0 ]; then
        error "Unable to connect to $HOST:$PORT"
    fi

    ## generate request
    # XXX: if we want to make this easy, then we can just refuse chunked
    #      encoding in the request
    cat <<EOR 1>&3
$METHOD $RESOURCE HTTP/1.1
Host: $HOST
User-Agent: $USERAGENT

EOR
    ## read result
    read -u 3 -t $TIMEOUT reply
    return_code=$( echo "$reply" | cut -f 2 -d ' ' )
    return_message=$( echo "$reply" | cut -f 3 -d ' ' )

    ## decide what error code to return
    if [[ $( echo $return_code | grep -e "^2") ]]; then
        #2?? == okay
        return_code=0
    else
        #anything else is failure
        return_code=1
    fi

    ## read headers
    declare -a headers=()   #FIXME: if we making this global, other functions
                            #       can see our results
    while read -u 3 -t $TIMEOUT reply; do
        reply=$( echo "$reply" | tr -d '\r' ) #fuck all newlines
        if [ -z "$reply" ]; then
            break
        fi
        headers=( "${headers[@]}" "$reply" )
    done

    ## if the content length was specified, read that number of bytes
    bytes=$( getItem Content-Length "${headers[@]}" )
    if [ ! -z "$bytes" ]; then
        read -d '' -u 3 -t $TIMEOUT -n $bytes res
        echo "$res"
        exec 3<&-
        return $return_code
    fi

    ## if encoding is chunked, then perform some magic
    encoding=$( getItem Transfer-Encoding "${headers[@]}" )
    if [ $encoding == "chunked" ]; then
        while read -u 3 -t $TIMEOUT reply; do
            reply=$( echo "$reply" | tr -d '\r\n' ) #fuck all newlines
            bytes=$( hex2int "$reply" )

            # we're done
            if [[(-z $bytes) || ($bytes = 0)]]; then
                break
            fi

            # read the bytes left
            read -d '' -u 3 -t $TIMEOUT -n $bytes res
            echo "$res"
        done
        exec 3<&-
        return $return_code
    fi

    ## fallback (let's pray this covers everything i forgot)
    cat <&3
    exec 3<&-

    return $return_code
}

function httpClient()
{

    URL=$1
    if [ $# -ne 1 ]
    then
        echo "Usage: `basename $0` url"
        exit 1
    elif echo $URL | grep -E -q '^http://'                                # url must start with http
    then
        oldIFS=$IFS
        IFS=/
        set -- $URL
        HOST=$3                                         # Get the host
        RESOURCE=""
        shift 3
        while [ $# -gt 0 ]
        do
            RESOURCE="$RESOURCE/$1"                             # Get the resouce
            shift
        done
        IFS=$oldIFS
        if [ -z $RESOURCE ] || echo $URL | grep -E -q '/$'                    # If empty or url ends in /, add /
        then
            RESOURCE="$RESOURCE/"
        fi
#        exit
#        if ! ping -c 1 -q $HOST 2>&1 >/dev/null                         # Make sure its on the network. What if not
#                                                    # accepting pings? Maybe we don't even care.
#                                                    # Not sure how bash responds when the host
#                                                    # is not reachable
#        then
#            echo "$HOST not found"
#            exit 1
#        fi
    else
        echo "$URL not a valid URL. Must start with http://"
        exit 1
    fi

#    exec 2>&-   # XXX: silence all bash connection errors because we're dicks
    httpRequest $HOST 80 GET $RESOURCE  # XXX

#    exec 3<> /dev/tcp/$HOST/80      # Open connection
#    echo "GET $RESOURCE HTTP/1.1" 1>&3  # Request resource, only care about gets.
#    echo "host: $HOST" 1>&3         # Send host header, what about encoding?
#    echo 1>&3               # End request
#    BODY=1                  # Headers are done flag
#    HEADERS=""              # Store headers, maybe use later
#    TIMEOUT=30              # After initial connection we will only wait 1 second for timeout
#    while true
#    do
#        read -u 3 -t $TIMEOUT REPLY || break    # read from server or be done with it
#        LINE=$( echo $REPLY | tr -d '\r' )  # Eliminate \r, we are using UNIX
#        if [ $BODY -eq 0 ]
#        then
#            echo "$LINE"            # If after headers, print
#        elif echo $LINE | grep -E -q '^$'
#        then
#            BODY=0              # End of headers
#            TIMEOUT=1           # Read takes a long to die after the connection is done, make
#                            # it timeout after 1 second after the server is giving us data
#        else
#            HEADERS="$HEADERS\n$LINE"   # Save headers, for no reason
#        fi
#    done
#    exec 3<&-
}

httpClient $*


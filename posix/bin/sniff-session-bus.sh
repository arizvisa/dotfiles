#!/usr/bin/env bash
if [ -z "$1" ]; then
    printf 'Usage: %s local-socket [-d] [-x] [..socat parameters..]\n' "$0" 1>&2
    exit 1
fi

# Check the first parameter
if [ -e "$1" ]; then
    printf 'Error: address of local socket (%s) already exists!\n' "$1" 1>&2
    exit 1
fi
local_address="$1"
shift

# Check the endpoint that we're proxying into
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    printf 'Error: environment variable containing endpoint (DBUS_SESSION_BUS_ADDRESS) is empty!\n' 1>&2
    exit 1
fi
bus_address=`sed 's/^[^=]\+=\(.*\)$/\1/' <( printenv DBUS_SESSION_BUS_ADDRESS )`

# Use socat to proxy a socket to our bus address
socat -v "$@" UNIX-LISTEN:$local_address,mode=0666,reuseaddr,fork UNIX-CONNECT:$bus_address

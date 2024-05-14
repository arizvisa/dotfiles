#!/bin/sh
property="Device Enabled"
format=8
enabled=1
disabled=0

IFS== read _ id < <( xinput --list | grep -e "AT.*keyboard" | cut -f2 )
xinput --list | grep "id=$id"
xinput --list-props "$id"

case "$1" in
    [oO][nN])
        value="$enabled"
        ;;
    [oO][fF][fF])
        value="$disabled"
        ;;
    *)
        printf "%s: need '%s' or '%s'\n" "$0" on off
        exit 1
        ;;
esac

xinput --set-prop --type=int "$id" "$property" "$value"

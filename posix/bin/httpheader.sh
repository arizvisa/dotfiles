#!/usr/bin/env bash
CURL=`type -P curl.sh || type -P curl`
headers_as_json=( -w '%{header_json}' )
headers_silent=( -I -o /dev/null )
headers_request_method=( -X GET )

for parameter in "$@"; do
    if [ "${parameter}" == '-X' ]; then
        headers_request_method=()
    fi
done

exec ${CURL} "${headers_silent[@]}" "${headers_as_json[@]}" "${headers_request_method[@]}" "$@"

#!/bin/sh
CURL_PARAMS=(--silent --globoff --location --no-buffer --path-as-is)

HTTP_USER_AGENT=${HTTP_USER_AGENT:-'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.96 Safari/537.4'}
CURL_PARAMS=("${CURL_PARAMS[@]}" --user-agent "$HTTP_USER_AGENT")

# wtf, curl. why are these only available in libcurl?
[ -z "$CURLOPT_COOKIE" ] ||     CURL_PARAMS=("${CURL_PARAMS[@]}" "-b $CURLOPT_COOKIE")
[ -z "$CURLOPT_COOKIEFILE" ] || CURL_PARAMS=("${CURL_PARAMS[@]}" "-b $CURLOPT_COOKIEFILE")
[ -z "$CURLOPT_COOKIEJAR" ] ||  CURL_PARAMS=("${CURL_PARAMS[@]}" "-c $CURLOPT_COOKIEJAR")

curl "${CURL_PARAMS[@]}" "$@"

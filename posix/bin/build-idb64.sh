path=`dirname "$0"`
arg0=`basename "$0"`
prog=`type -P "build-idb.sh"`
exec -a "${path}/${arg0}" "${prog}" "$@"

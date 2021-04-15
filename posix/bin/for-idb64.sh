path=`dirname "$0"`
arg0=`basename "$0"`
prog=`type -P "for-idb.sh"`
exec -a "${path}/${arg0}" "${prog}" "$@"

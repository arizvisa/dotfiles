#!/bin/sh
input=$(cygpath -w "$1" | sed 's/\//\\/g')
output=$(basename "$1")

if test -z "$output"; then
    echo "Usage: $0 file"
    echo "Builds an ida database for file. Writes output to file.log"
    exit 1
fi

if test ! -f "$input"; then
    echo "Path $input not found."
    exit 1
fi

# poorly determine path to ida
path=$(resolvepath /c/Program\ Files*/IDA*)
if echo "$0" | grep -q 64; then
    ida="$path/idaq64.exe"
else
    ida="$path/idaq.exe"
fi
ida=$(cygpath -w "$ida")

# files for ida to write to
output="$output.idb"
error="$output.log"
tmp=".ida.analysis.$$.py"

makeanalysis()
{
    cat <<EOF
import _idaapi,time
print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
_ = time.time()
print "build-idb.sh:waiting for ida's auto-analysis to finish (%s)"% (time.asctime(time.localtime()))
_idaapi.autoWait()
print "build-idb.sh:finished in %.3f seconds (%s)"% (time.time()-_, time.asctime(time.localtime()))
print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
_idaapi.save_database(_idaapi.cvar.database_idb, 0)
_idaapi.qexit(0)
EOF
}

tmpunix="$(cygpath -u ./)/$tmp"
tmpwin="$(cygpath -s ./)\\$tmp"
makeanalysis >| "$tmpunix"
trap "rm -f \"./$tmpunix\"; exit $?" INT TERM EXIT
if test -f "$output"; then
    echo [$(date)] rebuilding "$output" for "$input"
else
    echo [$(date)] building "$output" for "$input"
fi

"$ida" -B -A "-S\"$tmpwin\"" -c -P -L$error -o$output "$input"

echo [$(date)] completed "$output" for "$input"
rm -f "$tmpunix"
trap - INT TERM EXIT

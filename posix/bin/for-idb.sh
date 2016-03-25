#!/bin/sh
input="$1"
script="$2"
shift 2

if test -z "$input" -o -z "$script"; then
    echo "Usage: $0 file.idb script [script-arguments...]"
    echo "Executes an ida script for file.idb"
    exit 1
fi
if test ! -f "$input"; then
    echo "Database $input not found."
    exit 1
fi
if test ! -f "$script"; then
    echo "Script $script not found."
    exit 1
fi

path=$(resolvepath /c/Program\ Files*/IDA*)
if echo "$0" | grep -q 64; then
    ida="$path/idaq64.exe"
else
    ida="$path/idaq.exe"
fi
progress="$input.log"
tmp=".ida.runscript$$.py"

runscript()
{
    #export script="$1"
    script="$1" cat <<EOF
import __builtin__,sys,time
for _ in ('traceback','logging','os','_idaapi','idaapi','idc','idautils','PySide'):
    try:
        globals()[_] = __builtin__.__import__(_)
    except ImportError:
        print "for-idb.sh:unable to import module %s. skipping."% _
    continue
#print "for-idb.sh:waiting for ida's autoanalysis to finish anything it missed (%s):%s"% ("$script", time.asctime(time.localtime()))
#_idaapi.autoWait()
print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
__builtin__._ = time.time()
print "for-idb.sh:executing %s (%s)"% ("$script", time.asctime(time.localtime()))
try: sys.dont_write_bytecode = True
except AttributeError: pass
try: execfile("$script", globals())
except: print 'for-idb.sh:Exception raised:%s\n'%(repr(sys.exc_info()[1])) + ''.join('for-idb.sh:%s'%_ for _ in traceback.format_exception(*sys.exc_info()))
print "for-idb.sh:completed %s in %.3f seconds (%s)"% ("$script", time.time()-__builtin__._, time.asctime(time.localtime()))
print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
print "for-idb.sh:saving %s"% ("$script")
_idaapi.save_database(_idaapi.cvar.database_idb, 0)
_idaapi.qexit(0)
EOF
}

runscript "$script" >| $tmp
trap "rm -f $tmp; exit $?" INT TERM EXIT
echo [$(date)] running "$script" on "$input"
#"ida" -A -L$progress -S"$tmp" "$input" 
"$ida" -A -L$progress -S"$tmp $*" "$input" 
echo [$(date)] completed "$script" on "$input"
rm -f $tmp
trap - INT TERM EXIT

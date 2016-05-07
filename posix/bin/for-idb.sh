#!/bin/sh
arg0=`basename "$0"`
input="$1"
script="$2"
shift 2

if test -z "$input" -o -z "$script"; then
    printf "Usage: %s file.idb script [script-arguments...]\n" "$0" 1>&2
    printf "Executes an ida script for file.idb\n" 1>&2
    exit 1
fi

currentdate()
{
    date --rfc-3339=seconds
}

logprefix()
{
    arg0=`basename "$0"`
    if test "$#" -gt 0; then
        current="$1"
    else
        current=`currentdate`
    fi
    printf "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    printf "+ $arg0 began at : %s\n" "$current"
    printf "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
}

logsuffix()
{
    arg0=`basename "$0"`
    if test "$#" -gt 0; then
        current="$1"
    else
        current=`currentdate`
    fi
    printf "====================================================================================================================================\n"
    printf "= $arg0 completed at : %s\n" "$current"
    printf "====================================================================================================================================\n"
}

if test ! -f "$input"; then
    printf "[%s] Database %s not found.\n" "`currentdate`" "$input" 1>&2
    exit 1
fi
if test ! -f "$script"; then
    printf "[%s] Script %s not found.\n" "`currentdate`" "$script" 1>&2
    exit 1
fi


# poorly determine path to ida
idapath=`resolvepath /c/Program\ Files*/IDA*`
if echo "$0" | grep -q 64; then
    ida="$idapath/idaq64.exe"
    idaext="i64"
else
    ida="$idapath/idaq.exe"
    idaext="idb"
fi
ida=`cygpath -w "$ida"`

progress=".ida.runscript.$$.log"
tmp=".ida.runscript.$$.py"

runscript()
{
    #export script="$1"
    script="$1" cat <<EOF
import __builtin__,sys,time
for _ in ('traceback','logging','os','_idaapi','idaapi','idc','idautils','PySide'):
    try:
        globals()[_] = __builtin__.__import__(_)
    except ImportError:
        print "$arg0:unable to import module %s. skipping."% _
    continue
#print "%s:waiting for ida's autoanalysis to finish anything it missed (%s):%s"% ("$arg0", "$script", time.asctime(time.localtime()))
#_idaapi.autoWait()
print "~"*132
__builtin__._ = time.time()
print "%s:executing %s (%s)"% ("$arg0", "$script", time.asctime(time.localtime()))
try: sys.dont_write_bytecode = True
except AttributeError: pass
try: execfile("$script", globals())
except: print '%s:Exception raised:%s\n'%("$arg0", repr(sys.exc_info()[1])) + ''.join(':'.join(("$arg0", _)) for _ in traceback.format_exception(*sys.exc_info()))
print "%s:completed %s in %.3f seconds (%s)"% ("$arg0", "$script", time.time()-__builtin__._, time.asctime(time.localtime()))
print "~"*132
print "%s:saving %s"% ("$arg0", "$script")
_idaapi.save_database(_idaapi.cvar.database_idb, 0)
_idaapi.qexit(0)
EOF
}

runscript "$script" >| $tmp
trap 'rm -f "$tmp" "$progress"; exit $?' INT TERM EXIT
printf "[%s] running \"%s\" on \"%s\"\n" "`currentdate`" "$script" "$script" "$input"
beginning=`currentdate`
#"ida" -A -L$progress -S"$tmp" "$input"
"$ida" -A -L$progress -S"$tmp $*" "$input"
ending=`currentdate`
trap - INT TERM EXIT

clog=".ida.runscript.$$.clog"
logfile=`basename "$input" ".$idaext"`.log
if test -f "$logfile"; then
    printf "[%s] appending log from \"%s\" to \"%s\"\n" "`currentdate`" "$progress" "$logfile"
    mv -f "$logfile" "$clog"
    logprefix "$beginning" >> "$clog"
    cat "$clog" "$progress" >| "$logfile"
    logsuffix "$ending" >> "$logfile"
else
    printf "[%s] writing log to \"%s\"\n" "`currentdate`" "$logfile"
    mv -f "$progress" "$clog"
    logprefix "$beginning" >| "$logfile"
    cat "$clog" >> "$logfile"
    logsuffix "$ending" >> "$logfile"
fi
printf "[%s] completed \"%s\" on \"%s\"\n" "`currentdate`" "$script" "$input"
rm -f "$clog" "$progress" "$tmp"

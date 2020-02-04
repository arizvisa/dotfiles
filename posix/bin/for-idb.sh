arg0=`basename "$0"`
input="$1"
script="$2"
shift 2

echo "$arg0" | grep -q 64 && bits=64 || bits=32

if test -z "$input" -o -z "$script"; then
    test "$bits" -eq 64 && ext=i64 || ext=idb
    printf "Usage: %s file.%s script [script-arguments...]\n" "$0" "${ext}" 1>&2
    printf "Executes an ida script for file.%s\n" "${ext}" 1>&2
    exit 1
fi

getportablepath()
{
    case "$os" in
    windows)
        cygpath -w "$1"
        ;;
    *)
        cygpath -u "$1"
        ;;
    esac
    return 0
}

get_idabinary32()
{
    case "$os" in
    windows)
        if test -e "$1/idaq.exe"; then
            echo "$1/idaq.exe"
        else
            echo "$1/ida.exe"
        fi
        ;;
    *)
        if test -z "$DISPLAY" || test -z "$XAUTHORITY"; then
            echo "$1/idat"
        else
            echo "$1/ida"
        fi
    esac
}

get_idabinary64()
{
    case "$os" in
    windows)
        if test -e "$1/idaq.exe"; then
            echo "$1/idaq64.exe"
        else
            echo "$1/ida64.exe"
        fi
        ;;
    *)
        if test -z "$DISPLAY" || test -z "$XAUTHORITY"; then
            echo "$1/idat64"
        else
            echo "$1/ida64"
        fi
    esac
}

find_idapath()
{
    local path="$IDAPATH"
    local file="ida.hlp"
    local programfiles=`resolvepath "$ProgramFiles"`

    if test -z "$path" && test -d "$programfiles"; then
        local IFS=$'\n\t'
        for cp in $programfiles*/IDA*; do
            rp=`resolvepath "$cp"`
            if test -e "$rp/$file"; then
                path=$rp
                break
            fi
        done
    fi

    # if we couldn't find anything, then bail
    test -z "$path" && return 1

    # otherwise emit it to the caller
    echo "$path"
}


currentdate()
{
    date --rfc-3339=seconds
}

logprefix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf "+--------------------------------------------------------------------------------------------\n"
    printf "| $arg0 began at : %s\n" "$current"
    printf "+--------------------------------------------------------------------------------------------\n"
}

logsuffix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf "+============================================================================================\n"
    printf "| $arg0 completed at : %s\n" "$current"
    printf "+============================================================================================\n"
}

if test ! -f "$input"; then
    printf "[%s] Database %s not found.\n" "`currentdate`" "$input" 1>&2
    exit 1
fi
if test ! -f "$script"; then
    printf "[%s] Script %s not found.\n" "`currentdate`" "$script" 1>&2
    exit 1
fi

# try to resolve its path and bitch if we can't find it
idapath=`find_idapath`

if test "$?" -gt 0; then
    printf "[%s] unable to determine path to ida. use the environment varible %s.\n" "`currentdate`" "IDAPATH" 1>&2
    exit 1
fi

if ! test -d "$idapath"; then
    printf "[%s] unable to resolve ida path \"%s\" to a directory.\n" "`currentdate`" "$idapath" 1>&2
    exit 1
fi

# poorly determine path to ida
if echo "$0" | grep -q 64; then
    ida=`get_idabinary64 "$idapath"`
    idaext="i64"
else
    ida=`get_idabinary32 "$idapath"`
    idaext="idb"
fi
ida=`getportablepath "$ida"`

# utility files that get used by IDA
progress=".ida.runscript.$$.log"
tmp=".ida.runscript.$$.py"

# full path to the script the user wants to execute
inputpath=`realpath "$input"`
scriptpath=`realpath "$script"`

# used to find logfile
inputdir=`dirname "$inputpath"`

# used by runscript
scriptname=`basename "$scriptpath"`
scriptpath=`getportablepath "$scriptpath"`

runscript()
{
    script="$1"
    scriptpath="$2"
    workingdir="$3"

    cat <<EOF
import __builtin__,sys,time,os
sys.argv = __import__('idc').ARGV = ['$script'] + (__import__('idc').ARGV[1:] if len(__import__('idc').ARGV) else [])
os.chdir(r"$workingdir")
for _ in ('traceback','logging','os','idaapi','idaapi','idc','idautils'):
    try:
        globals()[_] = __builtin__.__import__(_)
    except ImportError:
        print "$arg0:unable to import module %s. skipping."% _
    continue
#print "%s:waiting for ida's autoanalysis to finish anything it missed (%s):%s"% ("$arg0", "$script", time.asctime(time.localtime()))
#idaapi.auto_wait()
print "~"*70
__builtin__._ = time.time()
print "%s:executing %s (%s) : %r"% ("$arg0", "$script", time.asctime(time.localtime()), sys.argv)
try: sys.dont_write_bytecode = True
except AttributeError: pass
try: execfile(r"$scriptpath", globals())
except: print '%s:Exception raised:%s\n'%("$arg0", repr(sys.exc_info()[1])) + ''.join(':'.join(("$arg0", _)) for _ in traceback.format_exception(*sys.exc_info()))
print "%s:completed %s in %.3f seconds (%s)"% ("$arg0", "$script", time.time()-__builtin__._, time.asctime(time.localtime()))
print "~"*70
print "%s:saving to %s"% (r"$arg0", r"$input")
if not hasattr(idaapi, 'get_kernel_version') or int(str(idaapi.get_kernel_version()).split('.', 2)[0]) < 7:
    idaapi.save_database(idaapi.cvar.database_idb, 0)
else:
    idaapi.save_database(idaapi.get_path(idaapi.PATH_TYPE_IDB), 0)
idaapi.qexit(0)
EOF
}

workingdir=`getportablepath .`
runscript "$scriptname" "$scriptpath" "$workingdir" >| $tmp
trap 'rm -f "$tmp" "$progress"; exit $?' INT TERM EXIT

printf "[%s] running \"%s\" against \"%s\"\n" "`currentdate`" "$script" "$input"

beginning=`currentdate`
#"ida" -A -L$progress -S"$tmp" "$input"
#"$ida" -A -L$progress -S"$tmp $*" "$input"
unquoted=("$@")
quoted=(${unquoted[@]/#/\"})
quoted=(${quoted[@]/%/\"})
tmppath_ida=`getportablepath "$tmp"`
progresspath_ida=`getportablepath "$progress"`
"$ida" -A "-L$progresspath_ida" -S"\"$tmppath_ida\" ${quoted[*]}" "$input"
ending=`currentdate`
trap - INT TERM EXIT

clog=".ida.runscript.$$.clog"
logfile="$inputdir/"`basename "$input" ".$idaext"`.log
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

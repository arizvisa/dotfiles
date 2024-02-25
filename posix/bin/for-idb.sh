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

# This takes a relative path and echos an absolute path (realpath) converting
# the '/' path separator to the one for your platform ('/' or '\').
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

# This function should echo the full path to your instance of IDA,
# using '/' as its path delimiter, and returns 1 on failure.
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


currentdate()
{
    date --rfc-3339=seconds
}

awklength()
{
    awk 'length > maximum { maximum=length } END { print maximum }'
}

allahu_awkbar()
{
    width="$1"
    test "$#" -gt 1 && horizontal="$2" || horizontal='-'
    test "$#" -gt 2 && vertical="$3" || vertical='| '
    test "$#" -gt 3 && corner="$4" || corner='+'
    awk -v "vert=$vertical" -v "horz=$horizontal" -v "corn=$corner" -v "width=$width" 'function rep(count, char, agg) { while (0 < count--) { agg = agg char } return agg } BEGIN { print corn rep(width - length(corn), horz, "") } END { print corn rep(width - length(corn), horz, "") } { print vert $0 }'
}

logfile_begin()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf '%s began at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '-'
}

logfile_end()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf '\n'
    printf '%s completed at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '='
}

logfile_abort()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf '\n'
    printf '%s failed at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '~'
}

unbase() { tr 'a-z' 'A-Z' | cat <( printf 'ibase=%d\n' "$1") - | bc; }
chunk() { dd iflag=skip_bytes "skip=$1" count="$2" bs="$3" 2>/dev/null | od -Anone -tx$3 | xargs printf '%s\n'; }
check_header()
{
    infile="$1"

    # https://github.com/williballenthin/python-idb
    read _version < <(dd "if=$infile" skip=30 bs=1 count=2 2>/dev/null | od -Anone -tx2 | tr -d ' ' | xargs printf 'ibase=%d; %s\n' 16 | bc)
    [ $_version -le 4 ] && length=4 || length=8
    if [ $_version -le 4 ]; then
        printf '%d %d\n' 6 5 58 1
    else
        printf '%d %d\n' 6 2 32 3 76 1
    fi | while read offset count; do
        <"$infile" chunk $offset $count $length
    done | unbase 16 | grep -v -e '^0$' | while read offset; do
        chunk $offset 1 1 <"$infile" | unbase 16
        expr 1 + $offset | xargs printf '%d\n' $length 1 | tac | paste -s -d ' '
        expr 1 + $length + $offset
    done | paste -d $'\t' - - - | while IFS=$'\t' read shtype shlazysize shdata; do
        read size < <( chunk $shlazysize <"$infile" | unbase 16 )
        if [ $shtype -eq 2 ]; then
            <"$infile" dd iflag=skip_bytes skip=$shdata bs=1 skip=$shdata count=$size 2>/dev/null | cat <( printf '\x1f\x8b\x08\x00\x00\x00\x00\x00') - | zcat | xxd
            break
        else
            echo nozlib $shdata $size
        fi
    done
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
import builtins, sys, time, os
sys.argv = __import__('idc').ARGV = [r"$script"] + (__import__('idc').ARGV[1:] if len(__import__('idc').ARGV) else [])
os.chdir(r"$workingdir")
for module in ['traceback','logging','os','idaapi','idaapi','idc','idautils']:
    try:
        globals()[module] = __import__(module)
    except ImportError:
        print("[%s] (%s) unable to import module %s... continuing anyways."% (time.asctime(time.localtime()), r"$arg0", module))
    continue
del(module)
#print("[%s] (%s) waiting for ida's autoanalysis to finish processing %s before running %s (%r)"% (time.asctime(time.localtime()), r"$arg0", idaapi.get_path(idaapi.PATH_TYPE_IDB), r"$script", sys.argv))
#idaapi.auto_wait()
print("~"*90)
builtins.clock = (lambda: time.time_ns() * 1e-9) if hasattr(time, 'time_ns') else time.time
builtins._ = builtins.clock()
print("[%s] (%s) running %s (%r) against %s"% (time.asctime(time.localtime()), r"$arg0", r"$script", sys.argv, idaapi.get_path(idaapi.PATH_TYPE_IDB)))
try: sys.dont_write_bytecode = True
except AttributeError: pass
try: exec(compile(open(r"$scriptpath").read(), r"$scriptpath", 'exec'), globals())
except SystemExit:
    builtins.__EXITCODE__, = sys.exc_info()[1].args
    builtins.__ABORT__ = True
except Exception:
    builtins.__ABORT__ = True
    print('[%s] (%s) caught unhandled exception running %s (%r): %s\n\n%s\n'%(time.asctime(time.localtime()), r"$arg0", r"$script", sys.argv, repr(sys.exc_info()[1]), ''.join('[%s] (%s) %s'% (time.asctime(time.localtime()), r"$arg0", _) for _ in traceback.format_exception(*sys.exc_info())).rstrip('\n')))
else:
    builtins.__ABORT__ = False
print("[%s] (%s) execution of %s (%r) against %s %s in %.5f seconds"% (time.asctime(time.localtime()), r"$arg0", r"$script", sys.argv, idaapi.get_path(idaapi.PATH_TYPE_IDB), 'terminated' if builtins.__ABORT__ and getattr(builtins, '__EXITCODE__', 0) else 'completed', builtins.clock()-builtins._))
print("~"*90)
print("[%s] (%s) aborting save of database (%s) after running %s (%r) due to %s"% (time.asctime(time.localtime()), r"$arg0", idaapi.get_path(idaapi.PATH_TYPE_IDB), r"$script", sys.argv, "script exit (error: %d)"% getattr(builtins, '__EXITCODE__', 0) if hasattr(builtins, '__EXITCODE__') else 'unhandled exception')) if builtins.__ABORT__ else print("[%s] (%s) saving current state of database to %s after running %s (%r)"% (time.asctime(time.localtime()), r"$arg0", idaapi.get_path(idaapi.PATH_TYPE_IDB), r"$script", sys.argv))
if builtins.__ABORT__:
    idaapi.set_database_flag(idaapi.DBFL_KILL)  # thanks to rolf and (indirectly) misty
elif not hasattr(idaapi, 'get_kernel_version') or int(str(idaapi.get_kernel_version()).split('.', 2)[0]) < 7:
    builtins._ = builtins.clock()
    idaapi.save_database(idaapi.cvar.database_idb, idaapi.DBFL_COMP | idaapi.DBFL_BAK)
    print("[%s] (%s) succesfully wrote database to %s in %.5f seconds"% (time.asctime(time.localtime()), r"$arg0", idaapi.get_path(idaapi.PATH_TYPE_IDB), builtins.clock()-builtins._))
else:
    builtins._ = builtins.clock()
    idaapi.save_database(idaapi.get_path(idaapi.PATH_TYPE_IDB), idaapi.DBFL_COMP | idaapi.DBFL_BAK)
    print("[%s] (%s) succesfully wrote database to %s in %.5f seconds"% (time.asctime(time.localtime()), r"$arg0", idaapi.get_path(idaapi.PATH_TYPE_IDB), builtins.clock()-builtins._))
idaapi.qexit(getattr(builtins, '__EXITCODE__', 1 if builtins.__ABORT__ else 0))
EOF
}

workingdir=`getportablepath .`
runscript "$scriptname" "$scriptpath" "$workingdir" >| $tmp
trap 'rm -f "$tmp" "$progress"; exit $?' INT TERM EXIT

beginning=`currentdate`
#"ida" -A -L$progress -S"$tmp" "$input"
#"$ida" -A -L$progress -S"$tmp $*" "$input"
unquoted=("$@")
quoted=(`printf "\"%s\" " "${unquoted[@]}"`)
tmppath_ida=`getportablepath "$tmp"`
progresspath_ida=`getportablepath "$progress"`
if [ "$#" -gt 0 ]; then
    printf "[%s] script \"%s\" started against \"%s\" with parameters: %s\n" "`currentdate`" "$script" "$input" "${quoted[*]}"
    "$ida" -A "-L$progresspath_ida" -S"\"$tmppath_ida\" ${quoted[*]}" "$input"
else
    printf "[%s] script \"%s\" started against \"%s\"\n" "`currentdate`" "$script" "$input"
    "$ida" -A "-L$progresspath_ida" -S"\"$tmppath_ida\"" "$input"
fi
result=$?
ending=`currentdate`
trap - INT TERM EXIT

clog=".ida.runscript.$$.clog"
logfile="$inputdir/"`basename "$input" ".$idaext"`.log
if test -f "$logfile"; then
    printf "[%s] appending log from \"%s\" to \"%s\"\n" "`currentdate`" "$progress" "$logfile"
    mv -f "$logfile" "$clog"
    logfile_begin "$beginning" >> "$clog"
    cat "$clog" "$progress" >| "$logfile"
else
    printf "[%s] writing log to \"%s\"\n" "`currentdate`" "$logfile"
    mv -f "$progress" "$clog"
    logfile_begin "$beginning" >| "$logfile"
    cat "$clog" >> "$logfile"
fi

if [ "$result" -gt 0 ]; then
    logfile_abort "$ending" >> "$logfile"
    printf "[%s] script \"%s\" failed (error: %d) on \"%s\"\n" "`currentdate`" "$script" "$result" "$input"
else
    logfile_end "$ending" >> "$logfile"
    printf "[%s] script \"%s\" completed on \"%s\"\n" "`currentdate`" "$script" "$input"
fi
rm -f "$clog" "$progress" "$tmp"
exit "$result"

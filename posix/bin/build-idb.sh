usage()
{
    printf "usage: %s [-P] [-n] [-o output] file [...ida parameters...]\n" "$1"
    echo "$1" | grep -q 64 && bits="64-bit" || bits="32-bit"
    printf "builds a %s ida database for file. writes output to file.{idb,log}.\n" "$bits"
}

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

    if [ -z "$path" ] && [ -d "$programfiles" ]; then
        local IFS=$'\n\t'
        for cp in $programfiles*/IDA*; do
            rp=`resolvepath "$cp"`
            if [ -e "$rp/$file" ]; then
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
        if [ -e "$1/idaq.exe" ]; then
            echo "$1/idaq.exe"
        else
            echo "$1/ida.exe"
        fi
        ;;
    *)
        if [ -z "$DISPLAY" ] || [ -z "$XAUTHORITY" ]; then
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
        if [ -e "$1/idaq.exe" ]; then
            echo "$1/idaq64.exe"
        else
            echo "$1/ida64.exe"
        fi
        ;;
    *)
        if [ -z "$DISPLAY" ] || [ -z "$XAUTHORITY" ]; then
            echo "$1/idat64"
        else
            echo "$1/ida64"
        fi
    esac
}

currentdate()
{
    printf '%(%Y-%m-%d %H:%M:%S%z)T\n'
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
    test "$#" -gt 4 && horizontal2="$5" || horizontal2='_'
    awk -v "vert=$vertical" -v "horz=$horizontal" -v "horz2=$horizontal2" -v "corn=$corner" -v "width=$width" 'function rep(count, char, agg) { while (0 < count--) { agg = agg char } return agg } BEGIN { print corn rep(width - length(corn), horz, "") } END { print corn rep(width - length(corn), horz2, "") } { print vert $0 }'
}

perlbar_rjustified()
{
    width="$1"
    test "$#" -gt 1 && horizontal="$2" || horizontal='-'
    test "$#" -gt 2 && corner="$3" || corner='+'
    with="$width" whorez="$horizontal" corn="$corner" perl -pe 'BEGIN{$whorez_and_corn=$ENV{corn}.$ENV{whorez};$whorez_and_corn=~s/(.)?(.)/$1.$2x$ENV{with}/e}; chomp;$_=" $_"unless $ENV{with}<=length;$_=substr($whorez_and_corn,0,$ENV{with}>length?$ENV{with}-length:0)."$_\n"'
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
    printf '%s failed at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '='
}

makeanalysis()
{
    arg0=`basename "$0"`
    cat <<EOF
import idaapi,time
print("^"*90)
clock = (lambda: time.time_ns() * 1e-9) if hasattr(time, 'time_ns') else time.time
ts = clock()
print("$arg0:waiting for ida's auto-analysis to finish (%s)"% (time.asctime(time.localtime())))
idaapi.auto_wait()
print("$arg0:finished in %.5f seconds (%s)"% (clock() - ts, time.asctime(time.localtime())))
print("~"*90)
print("%s:saving to %s"% (r"$arg0", r"$output"))
save_ts = clock()
if not hasattr(idaapi, 'get_kernel_version') or int(str(idaapi.get_kernel_version()).split('.', 2)[0]) < 7:
    idaapi.save_database(idaapi.cvar.database_idb, idaapi.DBFL_COMP)
else:
    idaapi.save_database(idaapi.get_path(idaapi.PATH_TYPE_IDB), idaapi.DBFL_COMP)
print("$arg0:saving took %.5f seconds (%s)"% (clock() - save_ts, time.asctime(time.localtime())))
print("$"*90)
idaapi.qexit(0)
EOF
}

# parse commandline
declare -a parameters=( "$@" )
let count=0
while [ "$count" -lt "${#parameters[@]}" ]; do
    parameter="${parameters[$count]}"
    case "$parameter" in
        -o) let count+=1    ;;
        -*) ;;
        *)  break
    esac
    let count+=1
done

# collect the options that came before the input filename.
declare -a options=()
let index=0
while [ "$index" -lt "$count" ]; do
    options+=( "${parameters[$index]}" )
    let index+=1
done
unset count

# set the options we collected and process them as usual.
set -- "${options[@]}"
plugin=0
dryrun=0
while getopts "h?o:Pn" opt; do
    case "$opt" in
        h|\?)
            usage "$0"
            exit 0
            ;;
        o)
            output="$OPTARG"
            ;;
        P)
            plugin=1
            ;;
        n)
            dryrun=1
            ;;
        *)
            break
    esac
done

# set the original parameters, but shifted by whatever options we processed.
set -- "${parameters[@]}"
shift "${#options[@]}"
unset options parameters

# if we don't have at least one parameter, then abort with the usage message.
if [ "$#" -lt 1 ]; then
    usage "$0" 1>&2
    exit 1
fi

# grab the input path
input=`getportablepath "$1"`

# extract paths to read from and write to
if [ -z "$output" ]; then
    output=`basename "$input"`
    outpath=`dirname "$input"`
    filename=`basename "$input"`
else
    outpath=`dirname "$output"`
    filename=`basename "$output"`
    printf "[%s] user specified output name as \"%s\"\n" "`currentdate`" "$outpath/$filename"
fi

if [ ! -f "$input" ] && [ ! -L "$input" ]; then
    printf "[%s] input path \"%s\" not found.\n" "`currentdate`" "$input" 1>&2
    exit 1
fi

# shift the input path we just validated
shift

# try to resolve its path and bitch if we can't find it
idapath=`find_idapath`

if [ "$?" -gt 0 ]; then
    printf "[%s] unable to determine path to ida. use the environment varible %s.\n" "`currentdate`" "IDAPATH" 1>&2
    exit 1
fi

if ! test -d "$idapath"; then
    printf "[%s] unable to resolve ida path \"%s\" to a directory.\n" "`currentdate`" "$idapath" 1>&2
    exit 1
fi

# figure out the path to an ida binary
if echo "$0" | grep -q 64; then
    ida=`get_idabinary64 "$idapath"`
    idaext="i64"
else
    ida=`get_idabinary32 "$idapath"`
    idaext="idb"
fi
ida_portable=`getportablepath "$ida"`

# check to see what user is trying to write to
ext=`echo "$filename" | sed 's/.*\.//'`
if [ "$ext" = "log" ]; then
    output=`basename "$filename" ".$ext"`
    if [ -f "$outpath/$output.$idaext" ]; then
        command="updating database"
    else
        command="writing database to"
    fi
    printf "[%s] user desires to log output to \"%s\".\n" "`currentdate`" "$outpath/$output.log"
    printf "[%s] %s \"%s\".\n" "`currentdate`" "$command" "$outpath/$output.$idaext"
    ext="$idaext"

elif [ "$ext" = "$idaext" ]; then
    output=`basename "$filename" ".$ext"`
    if [ -f "$outpath/$output.$idaext" ]; then
        command="update database"
    else
        command="write database to"
    fi
    printf "[%s] user desires to %s \"%s\".\n" "`currentdate`" "$command" "$outpath/$output.$idaext"
    printf "[%s] logging output to \"%s\".\n" "`currentdate`" "$outpath/$output.log"

else
    printf "[%s] writing database to \"%s\".\n" "`currentdate`" "$outpath/$output.$idaext"
    printf "[%s] logging output to \"%s\".\n" "`currentdate`" "$outpath/$output.log"
    ext="$idaext"
fi

# files for ida to write to
error="$output.log"
output="$output.$ext"
tmp=".ida.analysis.$$.py"

# create script that is going to be executed
tmppath=`realpath "$outpath/$tmp"`
tmppath_ida=`getportablepath "$outpath/$tmp"`
makeanalysis >| "$tmppath"

# back up error log
errortmp=".ida.prevlog.$error.$$"
if [ -f "$outpath/$error" ]; then
    printf "[%s] backing up current log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$error" "$outpath/$errortmp"
    cp -f "$outpath/$error" "$outpath/$errortmp"
    errorcat=1
    trap 'rm -f "$tmppath"; test ! -z "$errorcat" && printf "[%s] restoring previous log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$errortmp" "$outpath/$error" && mv -f "$outpath/$errortmp" "$outpath/$error"; exit $?' INT TERM EXIT
else
    trap 'rm -f "$tmppath"; exit $?' INT TERM EXIT

fi

# figure out what default parameters to use for ida
declare -a parameters=()
if [ "$plugin" -eq 0 ]; then
    parameters+=( -A -P+ "-L$error" "-S\"$tmppath_ida\"" )
else
    parameters+=( -A -P+ "-L$error" )
fi

# now we can run ida
if [ "$#" -gt 0 ]; then
    printf "[%s] passing extra arguments to ida:" "`currentdate`";
    printf " '%s'" "$@"
    printf "\n"
fi

beginning=`currentdate`
printf "[%s] working directory: %s\n" "`currentdate`" "$outpath"
if [ "$dryrun" -eq 0 ] && [ -f "$outpath/$output" ]; then
    printf "[%s] updating database \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida_portable" "${parameters[@]}" "$@" "$output" )
    result=$?
elif [ "$dryrun" -eq 0 ]; then
    printf "[%s] building database \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida_portable" -B -c "${parameters[@]}" "$@" "-o$output" "$input" )
    result=$?

# if we're doing a dry run, then figure out what kind of update we need to do.
elif [ -f "$outpath/$output" ]; then
    declare -a commandline=( "$ida_portable" "${parameters[@]}" "$@" "$output" )
    printf "[%s] database \"%s\" for \"%s\" would have been updated.\n" "`currentdate`" "$output" "$input"
    printf "[%s] command line: %s\n" "`currentdate`" "${commandline[*]@Q}"
    result=0
else
    declare -a commandline=( "$ida_portable" -B -c "${parameters[@]}" "$@" "-o$output" "$input" )
    printf "[%s] database \"%s\" for \"%s\" would have been created.\n" "`currentdate`" "$output" "$input"
    printf "[%s] command line: %s\n" "`currentdate`" "${commandline[*]@Q}"
    result=0
fi
ending=`currentdate`

if [ "$dryrun" -ne 0 ]; then
    trap - INT TERM EXIT
    rm -f "$tmppath" "$outpath/$errortmp"
    printf "[%s] finished building database \"%s\" for \"%s\".\n" "`currentdate`" "$output" "$input"
    exit 0

elif [ ! -e "$outpath/$error" ] && [ -e "$outpath/$errortmp" ]; then
    trap - INT TERM EXIT
    printf "[%s] error while updating ida database \"%s\". expected ida to write logfile to \"%s\"\n" "`currentdate`" "$output" "$outpath/$error"
    printf "[%s] restoring logfile from \"%s\"\n" "`currentdate`" "$errortmp"
    mv -f "$outpath/$errortmp" "$outpath/$error"
    rm -f "$tmppath"
    exit 1

elif [ ! -e "$outpath/$error" ]; then
    printf "[%s] error while building ida database \"%s\". expected ida to write logfile to \"%s\"\n" "`currentdate`" "$output" "$outpath/$error"
    rm -f "$tmppath"
    exit 1
fi

# surround logfile with timestamps
mv -f "$outpath/$error" "$outpath/.ida.log.$error.$$"
logfile_begin "$beginning" >| "$outpath/.ida.prefix.$error.$$"
cat "$outpath/.ida.prefix.$error.$$" "$outpath/.ida.log.$error.$$" >| "$outpath/$error"
rm -f "$outpath/.ida.prefix.$error.$$" "$outpath/.ida.log.$error.$$"

# check our result and update the log with whatever happened
[ "$result" -eq 0 ] && logfile_end "$ending" >> "$outpath/$error" || logfile_abort "$ending" >> "$outpath/$error"

# restore previous log to the beginning of the file
if [ ! -z "$errorcat" ]; then
    printf "[%s] combining previous log \"%s\" with \"%s\".\n" "`currentdate`" "$outpath/$errortmp" "$outpath/$error"
    errorcat=
    mv -f "$outpath/$error" "$outpath/.ida.log.$error.$$"
    cat "$outpath/$errortmp" "$outpath/.ida.log.$error.$$" >| "$outpath/$error"
    rm -f "$outpath/.ida.log.$error.$$" "$outpath/$errortmp"
fi

# check our result and see if it was okay
if [ "$result" -eq 0 ]; then
    printf "[%s] finished building database \"%s\" for \"%s\".\n" "`currentdate`" "$output" "$input"
else
    printf "[%s] error building database \"%s\" for \"%s\".\n" "`currentdate`" "$output" "$input"
fi

# and we're done. so do some cleanup
rm -f "$tmppath"
trap - INT TERM EXIT

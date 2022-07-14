usage()
{
    printf "usage: %s [-o output] file [...ida parameters...]\n" "$1"
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

logprefix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf '%s began at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '-'
}

logsuffix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf "\n"
    printf '%s completed at : %s\n' "$arg0" "$current" | allahu_awkbar 90 '='
}

makeanalysis()
{
    arg0=`basename "$0"`
    cat <<EOF
import idaapi,time
print("~"*65)
_ = time.time()
print("$arg0:waiting for ida's auto-analysis to finish (%s)"% (time.asctime(time.localtime())))
idaapi.auto_wait()
print("$arg0:finished in %.3f seconds (%s)"% (time.time()-_, time.asctime(time.localtime())))
print("~"*65)
print("%s:saving to %s"% (r"$arg0", r"$output"))
if not hasattr(idaapi, 'get_kernel_version') or int(str(idaapi.get_kernel_version()).split('.', 2)[0]) < 7:
    idaapi.save_database(idaapi.cvar.database_idb, 0)
else:
    idaapi.save_database(idaapi.get_path(idaapi.PATH_TYPE_IDB), 0)
idaapi.qexit(0)
EOF
}

# parse commandline
while getopts "h?o:" opt; do
    case "$opt" in
        h|\?)
            usage "$0"
            exit 0
            ;;
        o)
            output="$2"
            shift 2
            ;;
        *)
            break
    esac
done

if test "$#" -lt 1; then
    usage "$0" 1>&2
    exit 1
fi

# grab the input path
input=`getportablepath "$1"`

# extract paths to read from and write to
if test -z "$output"; then
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

if test "$?" -gt 0; then
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
ida=`getportablepath "$ida"`

# check to see what user is trying to write to
ext=`echo "$filename" | sed 's/.*\.//'`
if test "$ext" = "log"; then
    output=`basename "$filename" ".$ext"`
    if test -f "$outpath/$output.$idaext"; then
        command="updating"
    else
        command="writing to"
    fi
    printf "[%s] user wishes to log to \"%s\". %s \"%s\".\n" "`currentdate`" "$outpath/$output.log" "$command" "$outpath/$output.$idaext"
    ext="$idaext"

elif test "$ext" = "$idaext"; then
    output=`basename "$filename" ".$ext"`
    if test -f "$outpath/$output.$idaext"; then
        command="update"
    else
        command="write to"
    fi
    printf "[%s] user wishes to %s \"%s\". logging to \"%s\".\n" "`currentdate`" "$command" "$outpath/$output.$idaext" "$outpath/$output.log"

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
if test -f "$outpath/$error"; then
    printf "[%s] backing up current log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$error" "$outpath/$errortmp"
    mv "$outpath/$error" "$outpath/$errortmp"
    errorcat=1
    trap 'rm -f "$tmppath"; test ! -z "$errorcat" && printf "[%s] restoring previous log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$errortmp" "$outpath/$error" && mv -f "$outpath/$errortmp" "$outpath/$error"; exit $?' INT TERM EXIT
else
    trap 'rm -f "$tmppath"; exit $?' INT TERM EXIT

fi

# now we can run ida
if test "$#" -gt 0; then
    printf "[%s] passing extra arguments to ida:" "`currentdate`";
    printf " '%s'" "$@"
    printf "\n"
fi

beginning=`currentdate`
if test -f "$outpath/$output"; then
    printf "[%s] updating database \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida" -A "-S\"$tmppath_ida\"" -P+ "$@" "-L$error" "$output" )
    result=$?
else
    printf "[%s] building database \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida" -B -A "-S\"$tmppath_ida\"" -c -P+ "$@" "-L$error" "-o$output" "$input" )
    result=$?
fi
ending=`currentdate`

if test ! -e "$outpath/$error" && test -e "$outpath/$errortmp"; then
    trap - INT TERM EXIT
    printf "[%s] error while updating ida database \"%s\". expected ida to write logfile to \"%s\"\n" "`currentdate`" "$output" "$outpath/$error"
    printf "[%s] restoring logfile from \"%s\"\n" "`currentdate`" "$errortmp"
    mv -f "$outpath/$errortmp" "$outpath/$error"
    rm -f "$tmppath"
    exit 1

elif test ! -e "$outpath/$error"; then
    printf "[%s] error while building ida database \"%s\". expected ida to write logfile to \"%s\"\n" "`currentdate`" "$output" "$outpath/$error"
    rm -f "$tmppath"
    exit 1
fi

# surround logfile with timestamps
mv -f "$outpath/$error" "$outpath/.ida.log.$error.$$"
logprefix "$beginning" >| "$outpath/.ida.prefix.$error.$$"
cat "$outpath/.ida.prefix.$error.$$" "$outpath/.ida.log.$error.$$" >| "$outpath/$error"
rm -f "$outpath/.ida.prefix.$error.$$" "$outpath/.ida.log.$error.$$"
logsuffix "$ending" >> "$outpath/$error"

# restore previous log to the beginning of the file
if test ! -z "$errorcat"; then
    printf "[%s] inserting previous log \"%s\" into \"%s\".\n" "`currentdate`" "$outpath/$errortmp" "$outpath/$error"
    errorcat=
    mv -f "$outpath/$error" "$outpath/.ida.log.$error.$$"
    cat "$outpath/$errortmp" "$outpath/.ida.log.$error.$$" >| "$outpath/$error"
    rm -f "$outpath/.ida.log.$error.$$" "$outpath/$errortmp"
fi

# and we're done. so do some cleanup
printf "[%s] completed \"%s\" for \"%s\".\n" "`currentdate`" "$output" "$input"
rm -f "$tmppath"
trap - INT TERM EXIT

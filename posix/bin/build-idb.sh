usage()
{
    printf "usage: %s file [output]\n" "$1"
    echo "$1" | grep -q 64 && bits="64-bit" || bits="32-bit"
    printf "builds a %s ida database for file. writes output to file.{idb,log}.\n" "$bits"
}

currentdate()
{
    date --rfc-3339=seconds
}

logprefix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    printf "+ $arg0 began at : %s\n" "$current"
    printf "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"
}

logsuffix()
{
    arg0=`basename "$0"`
    test "$#" -gt 0 && current="$1" || current=`currentdate`
    printf "==============================================================================================================\n"
    printf "= $arg0 completed at : %s\n" "$current"
    printf "==============================================================================================================\n"
}

makeanalysis()
{
    arg0=`basename "$0"`
    cat <<EOF
import idaapi,time
print "~"*132
_ = time.time()
print "$arg0:waiting for ida's auto-analysis to finish (%s)"% (time.asctime(time.localtime()))
idaapi.autoWait()
print "$arg0:finished in %.3f seconds (%s)"% (time.time()-_, time.asctime(time.localtime()))
print "~"*132
idaapi.save_database(idaapi.cvar.database_idb, 0)
idaapi.qexit(0)
EOF
}

# parse commandline
args=`getopt -u -o h\? -l help -- $*`
if test "$?" -ne 0 -o "$#" -eq 0; then
    usage "$0" 1>&2
    exit 1
fi
set -- $args
while test "$#" -gt 0; do
    case "$1" in
        -h|-\?|--help) usage "$0"; exit 0 ;;
        --) shift; break ;;
    esac
done

# extract paths to read from and write to
input=`cygpath -w "$1" | sed 's/\//\\\/g'`
if test "$#" -gt 1; then
    output="$2"
    outpath=`dirname "$2"`
    filename=`basename "$2"`
else
    output=`basename "$1"`
    outpath=`dirname "$1"`
    filename=`basename "$1"`
fi

if test ! -f "$input"; then
    printf "[%s] path \"%s\" not found.\n" "`currentdate`" "$input" 1>&2
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

# check to see what user is trying to write to
ext=`echo "$filename" | sed 's/.*\.//'`
if test "$ext" == "log"; then
    output=`basename "$filename" ".$ext"`
    if test -f "$outpath/$output.$idaext"; then
        command="updating"
    else
        command="writing to"
    fi
    printf "[%s] user wishes to log to \"%s\". %s \"%s\".\n" "`currentdate`" "$outpath/$output.log" "$command" "$outpath/$output.$idaext"
    ext="$idaext"
elif test "$ext" == "$idaext"; then
    output=`basename "$filename" ".$ext"`
    if test -f "$outpath/$output.$idaext"; then
        command="update"
    else
        command="write to"
    fi
    printf "[%s] user wishes to %s \"%s\". logging to \"%s\".\n" "`currentdate`" "$command" "$outpath/$output.$idaext" "$outpath/$output.log"
else
    printf "[%s] logging to \"%s\". writing to \"%s\".\n" "`currentdate`" "$outpath/$output.log" "$outpath/$output.$idaext"
    ext="$idaext"
fi

# files for ida to write to
error="$output.log"
output="$output.$ext"
tmp=".ida.analysis.$$.py"

# create script that is going to be executed
tmpunix="`cygpath -u \"$outpath\"`/$tmp"
tmpwin="`cygpath -s \"$outpath\"`\\$tmp"
makeanalysis >| "$tmpunix"

# back up error log
if test -f "$outpath/$error"; then
    errortmp=".ida.prevlog.$error.$$"
    printf "[%s] backing up current log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$error" "$outpath/$errortmp"
    mv "$outpath/$error" "$outpath/$errortmp"
    errorcat=1
    trap 'rm -f "$tmpunix"; test ! -z "$errorcat" && printf "[%s] restoring previous log from \"%s\" to \"%s\".\n" "`currentdate`" "$outpath/$errortmp" "$outpath/$error" && mv -f "$outpath/$errortmp" $outpath/$error"; exit $?' INT TERM EXIT
else
    trap 'rm -f "$tmpunix"; exit $?' INT TERM EXIT

fi

# now we can run ida
beginning=`currentdate`
if test -f "$outpath/$output"; then
    printf "[%s] updating \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida" -A "-S\"$tmpwin\"" -P+ -L$error "$output" )
else
    printf "[%s] building \"%s\" for \"%s\"\n" "`currentdate`" "$output" "$input"
    ( cd "$outpath" && "$ida" -B -A "-S\"$tmpwin\"" -c -P+ -L$error -o$output "$input" )
fi
ending=`currentdate`

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
rm -f "$tmpunix"
trap - INT TERM EXIT

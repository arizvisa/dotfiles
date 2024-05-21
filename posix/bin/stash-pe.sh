#!/bin/sh
PYTHON=`which python`
[ -z "$SYRINGE" ] && SYRINGE=`python -c 'print(__import__("os").path.abspath(__import__("os").path.join(__import__("os").path.split(__import__("pecoff").__file__)[0], "..", "..")))'`

# some general functions...
usage()
{
    printf 'Usage: %s [-q] [-n] file path [peversionpath-options..]\n' "$1"
    printf 'Stashes a PE file to specified directory keyed by its version and then initializes an .idb\n'
}

logf()
{
    format="$1"; shift
    ts=`current_date`
    [ "$QUIET" -gt 0 ] || printf -- "[$ts] $format\n" "$@" 1>&2
}

fatalf()
{
    format="$1"; shift
    ts=`current_date`
    printf -- "[$ts] $format\n" "$@" 1>&2
}

current_date()
{
    date --rfc-3339=seconds
}

CWD=`pwd`
realize_path()
{
    case "$1" in
        /*) realpath -m -- "$1" ;;
        *) realpath --relative-to="$CWD" -m -- "$1" ;;
    esac
}

# verify that all of our requirements actually exist.
if [ ! -e "$SYRINGE/bin/pe.py" ] || [ ! -e "$SYRINGE/bin/peversionpath.py" ]; then
    fatalf 'Unable to locate required tools (pe.py, peversionpath.py) for parsing the portable executable format : %s' "$SYRINGE"
    exit 1
elif ! type -P realpath >/dev/null; then
    fatalf 'Unable to find required tool (%s) within the current path.' 'realpath'
    exit 1
fi

# set some defaults for the globals.
QUIET=0
DRYRUN=0

# getopt -T? really?? util-linux's getopt(1) is garbage. y'all
# should've really went the bell labs route. trust in bourne...
while getopts hqn? opt; do
    case "$opt" in
        h)
            HELP=1
            ec=0
            ;;
        q)
            QUIET=1
            ;;
        n)
            DRYRUN=1
            ;;
        *)
            HELP=2
            ec=1
            ;;
    esac
done
shift $(( $OPTIND - 1 ))

# verify we have the correct number of arguments.
if [ -z "$HELP" ] && [ $# -lt 2 ]; then
    fatalf '%s: not enough parameters -- got %d, but %d required' "$0" "$#" 2
    HELP=2
    ec=1
fi

# halp.
if [ ! -z "$HELP" ]; then
    usage "$0" 1>& $HELP
    exit $ec
fi

inpath="$1"
outdir="$2"
infile=`basename -- "$inpath"`
shift 2

if [ ! -d "$outdir" ] && [ "$DRYRUN" -ne 1 ]; then
    fatalf 'Specified path '\''%s'\'' not found or is not a directory.' "$outdir"
    exit 1
elif [ ! -r "$inpath" ]; then
    fatalf 'Specified path '\''%s'\'' not found or is not readable.' "$inpath"
    exit 1
fi

## figure out path to store pe into
logf 'Attempting to calculate the output path for "%s".' "$inpath"

# output all of the versions from $inpath that are sorted by their
# number of components and do not contain any whitespace.
get_version_format()
{
    available=('FileVersion' 'ProductVersion' 'VS_FIXEDFILEINFO.dwFileVersion' 'VS_FIXEDFILEINFO.dwProductVersion')
    #formats=`paste <( printf '{%s}\n' "${available[@]}") <( printf '%s\n' "${available[@]}")`
    #| awk -F. 'BEGIN {OFS = "\t"} /[^ ]/ {print NF,length($1),$2}' \
    formats=`printf '{%s}\n' "${available[@]}"`
    "$PYTHON" "$SYRINGE/bin/peversionpath.py" -f "$formats" -- "$1" 2>/dev/null \
    | awk -F. 'BEGIN {OFS = "\t"} {print NF,counter++,$0}' \
    | sort -rn \
    | grep -e $'^[0-9]\+\t[0-9]\+\t[0-9A-Za-z._]\+$' \
    | cut -d $'\t' -f2 | while read index; do
        printf '{%s}\n' "${available[$index]}"
    done
}

# if we were given some parameters, then use those to determine the output path
outpath=
if [ "$#" -gt 0 ]; then
    logf 'Trying to determine format for "%s" using parameters "%s".' "$inpath" "$*"
    outpath=`"$PYTHON" "$SYRINGE/bin/peversionpath.py" "$@" -- "$inpath" 2>/dev/null`
fi

# if the user chose an explicit path, then let them know that we're using it.
if [ "$?" -gt 0 ] || [ "`printf '%s' "$outpath" | wc -l`" -gt 0 ]; then
    fatalf 'Unable to format the path for "%s" using the parameters "%s".' "$inpath" "$*"
    [ -z "$outpath" ] || fatalf 'Output from the parameters "%s" was: %s' "$*" "$outpath"
    exit 1

# if we don't have an output path, then figure one out.
elif [ -z "$outpath" ]; then
    logf 'Attempting to determine best version information for "%s".' "$inpath"

    # first we need to figure out the best candidate for the version. we
    # fall back to the timestamp if we couldn't find a candidate.
    read version_format < <( get_version_format "$inpath" )
    if [ "$?" -gt 0 ]; then
        logf 'Unable to determine the best version from the VERSION_INFO record : %s' "$inpath"
        seconds=`stat -c %W -- "$inpath"`
        ts=`date --utc --date=@$seconds +%04Y%02m%02d.%02H%02M%02S`
        logf 'Falling back to creation timestamp (%s) for %s.' "$ts" "$inpath"
        version_format="$ts"
    fi

    # then we need a filename which requires us to try multiple possibilities.
    logf 'Attempting to determine filename for "%s".' "$inpath"
    formats_filename=('OriginalFilename' 'InternalName' '__name__')

    filename_format=
    for fmt in "${formats_filename[@]}"; do
        logf 'Attempting with format : %s' "$fmt"
        filename_format="{$fmt}"
        "$PYTHON" "$SYRINGE/bin/peversionpath.py" -f "{$fmt}" -- "$inpath" 2>/dev/null 1>/dev/null
        [ $? -eq 0 ] && break
        filename_format=
    done

    # if we couldn't get the filename, then use the original one.
    if [ -z "$filename_format" ]; then
        logf 'Unable to determine the path from the VERSION_INFO record : %s' "$inpath"
        filename_format="$infile"
        logf 'Falling back to input filename "%s" for %s.' "$infile" "$inpath"
    fi

    # now we can put our format back together and get the output path.
    format="{__name__~upper}/$version_format/$filename_format"
    outpath=`"$PYTHON" "$SYRINGE/bin/peversionpath.py" -f "$format" -- "$inpath" 2>/dev/null`
    logf 'Output path determined from version was "%s".' "$outpath"

else
    logf 'Output path determined from parameters was "%s".' "$outpath"
fi

# if we weren't supposed to build anything, then output our result and exit.
if [ "$DRYRUN" -gt 0 ]; then
    realize_path "$outdir/$outpath"
    exit 0
fi

# next step is to check to see if the file already exists and bail if it does.
outsubdir=`dirname -- "$outpath"`
outfile=`basename -- "$outpath"`

if [ -d "$outdir/$outsubdir" ] ; then
    if [ ! -f "$outdir/$outsubdir/$outfile" ]; then
        fatalf 'Output path "%s" already exists, but the filename (%s) does not.' "$outdir/$outsubdir" "$outfile"
        exit 1
    fi
    logf 'Output path "%s" and its file "%s" already exists.' "$outdir/$outsubdir" "$outdir/$outsubdir/$outfile"
    printf '%s\n' "$outdir/$outsubdir/$outfile"
    exit 0
fi

# figure out the machine type so that we can choose the correct disassembler to build with.
logf 'Attempting to determine the machine type for "%s"' "$inpath"
machine=`"$PYTHON" "$SYRINGE/bin/pe.py" -p --path 'FileHeader:Machine' -- "$inpath" 2>/dev/null`
if [ "$?" -gt 0 ]; then
    fatalf 'Error trying to parse PE file : %s' "$inpath"
    exit 1
fi
logf 'The PE machine type was determined as #%s.' "$machine"

case "$machine" in

    # 16-bit
    614|870|1126)
        builder="build-idb.sh" ;;

    # 32-bit
    332|352|354|361|387|388|418|419|420|422|424|448|450|452|467|496|497|3311|36929)
        builder="build-idb.sh" ;;

    # 64-bit
    358|360|512|644|34404|43620)
        builder="build-idb64.sh" ;;

    # mixed
    3772|49390)
        builder="build-idb64.sh" ;;

    *)
        fatalf 'Unsupported machine type (%s) when reading executable file : %s' "$machine" "$inpath"
        exit 1
        ;;
esac

# once we have the builder, dispatch to it in order to build the database.
logf 'Decided on %s to build the database.' "$builder"
(
    logf 'Carving a path to "%s".' "$outdir/$outsubdir/$outfile"
    mkdir -p -- "$outdir/$outsubdir"

    logf 'Dropping "%s" into "%s".' "$inpath" "$outdir/$outsubdir/$outfile"
    cp -- "$inpath" "$outdir/$outsubdir/$outfile"

    if [ "$infile" != "$outfile" ]; then
        logf 'Making a link from "%s" to the original name "%s".' "$outfile" "$infile"
        ln -sf -- "$outfile" "$outdir/$outsubdir/$infile" 2>/dev/null
    fi

    logf 'Now building the database for "%s".' "$outfile"
    cd -- "$outdir/$outsubdir"
    "$builder" "$outfile" 1>&2
)

# if building failed, then output an error message and clean up anything partially written.
if [ $? -gt 0 ]; then
    fatalf 'Unable to build database for file: %s' "$outdir/$outsubdir/$outfile"

    for file in "$outdir/$outsubdir/$outfile" "$outdir/$outsubdir/$infile"; do
        logf 'Cleaning file "%s" due to build failure.' "$file"
        rm -f -- "$file" 2>&2
    done

    logf 'Cleaning path "%s" due to build failure.' "$outdir/$outsubdir"
    cd "$outdir" && rmdir -p -- "$outsubdir" 1>&2
    exit 1
fi

logf 'Done!'

realize_path "$outdir/$outsubdir/$outfile"

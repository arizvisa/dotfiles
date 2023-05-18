#!/bin/sh
inpath="$1"
outdir="$2"
infile=`basename "$inpath"`

PYTHON=`which python`
test -z "$SYRINGE" && SYRINGE=`python -c 'print(__import__("os").path.abspath(__import__("os").path.join(__import__("os").path.split(__import__("pecoff").__file__)[0], "..", "..")))'`

if test -z "$inpath" -o "$#" -lt 2; then
    echo "Usage: $0 file path [peversionpath-options..]" 1>&2
    echo "Stashes a PE file to specified directory keyed by it's version and then pre-build's an .idb" 1>&2
    exit 1
fi
shift 2

if test ! -e "$SYRINGE/tools/pe.py" -o ! -e "$SYRINGE/tools/peversionpath.py"; then
    echo "Unable to locate tools (pe.py, peversionpath.py) for parsing the portable executable format : $SYRINGE" 1>&2
    exit 1
fi

if test ! -d "$outdir"; then
    echo "Specified path '$outdir' not found or is not a directory" 1>&2
    exit 1
fi

## figure out path to store pe into
echo "Attempting to calculate the output path for \"$inpath\"." 1>&2

# output all of the versions from $inpath that are sorted by their
# number of components and do not contain any whitespace.
get_version_format()
{
    available=('FileVersion' 'ProductVersion' 'VS_FIXEDFILEINFO.dwFileVersion' 'VS_FIXEDFILEINFO.dwProductVersion')
    #formats=`paste <( printf '{%s}\n' "${available[@]}") <( printf '%s\n' "${available[@]}")`
    #| awk -F. 'BEGIN {OFS = "\t"} /[^ ]/ {print NF,length($1),$2}' \
    formats=`printf '{%s}\n' "${available[@]}"`
    "$PYTHON" "$SYRINGE/tools/peversionpath.py" -f "$formats" "$1" 2>/dev/null \
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
    printf 'Trying to determine format for "%s" using parameters "%s".\n' "$inpath" "$*" 1>&2
    outpath=`"$PYTHON" "$SYRINGE/tools/peversionpath.py" "$@" "$inpath" 2>/dev/null`
fi

# if the user chose an explicit path, then let them know that we're using it.
if [ "$?" -gt 0 ] || printf '%s' "$outpath" | grep -qo '\n'; then
    printf 'Unable to format the path for "%s" using the parameters "%s".\n' "$inpath" "$*" 1>&2
    [ -z "$outpath" ] || printf 'Output from the parameters "%s" was:\n%s\n' "$*" "$outpath" 1>&2
    exit 1

# if we don't have an output path, then figure one out.
elif [ -z "$outpath" ]; then
    printf 'Attempting to determine best version information for "%s".\n' "$inpath" 1>&2

    # first we need to figure out the best candidate for the version. we
    # fall back to the timestamp if we couldn't find a candidate.
    read version_format < <( get_version_format "$inpath" )
    if test "$?" -gt 0; then
        printf 'Unable to determine the best version from the VERSION_INFO record : %s\n' "$inpath" 1>&2
        seconds=`stat -c %W "$inpath"`
        ts=`date --utc --date=@$seconds +%04Y%02m%02d.%02H%02M%02S`
        printf 'Falling back to creation timestamp (%s) for %s.\n' "$ts" "$inpath" 1>&2
        version_format="$ts"
    fi

    # then we need a filename which requires us to try multiple possibilities.
    printf 'Attempting to determine filename for "%s".\n' "$inpath" 1>&2
    formats_filename=('OriginalFilename' 'InternalName' '__name__')

    filename_format=
    for fmt in "${formats_filename[@]}"; do
        printf 'Attempting with format : %s\n' "$fmt" 1>&2
        filename_format="{$fmt}"
        "$PYTHON" "$SYRINGE/tools/peversionpath.py" -f "{$fmt}" "$inpath" 2>/dev/null 1>/dev/null
        [ $? -eq 0 ] && break
        filename_format=
    done

    # if we couldn't get the filename, then use the original one.
    if test -z "$filename_format"; then
        printf "Unable to determine the path from the VERSION_INFO record : %s\n" "$inpath" 1>&2
        filename_format="$infile"
        printf "Falling back to input filename "%s" for %s\n." "$infile" "$inpath" 1>&2
    fi

    # now we can put our format back together and get the output path.
    format="{__name__}/$version_format/$filename_format"
    outpath=`"$PYTHON" "$SYRINGE/tools/peversionpath.py" -f "$format" "$inpath" 2>/dev/null`
    printf 'Output path determined from version was "%s".\n' "$outpath" 1>&2

else
    printf 'Output path determined from parameters was "%s".\n' "$outpath" 1>&2
fi

# next step is to check to see if the file already exists and bail if it does.
outsubdir=`dirname "$outpath"`
outfile=`basename "$outpath"`

if [ -d "$outdir/$outsubdir" -a -f "$outdir/$outsubdir/$outfile" ]; then
    echo "Output path \"$outdir/$outsubdir\" and it's file \"$outdir/$outsubdir/$outfile\" already exists." 1>&2
    echo "$outdir/$outsubdir/$outfile"
    exit 0
fi

# figure out the machine type so that we can choose the correct disassembler to build with.
echo "Attempting to determine the machine type for \"$inpath\"" 1>&2
machine=`"$PYTHON" "$SYRINGE/tools/pe.py" -p --path 'FileHeader:Machine' "$inpath" 2>/dev/null`
if test "$?" -gt 0; then
    echo "Error trying to parse PE file : $inpath" 1>&2
    exit 1
fi
echo "The PE machine type was determined as #$machine." 1>&2

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
        echo "Unsupported machine type : $inpath" 1>&2
        exit 1
        ;;
esac

# once we have the builder, dispatch to it in order to build the database.
echo "Decided on $builder to build the database." 1>&2
(
    echo "Carving a path to \"$outdir/$outsubdir/$outfile\"." 1>&2
    mkdir -p "$outdir/$outsubdir"

    echo "Dropping \"$inpath\" into \"$outdir/$outsubdir/$outfile\"." 1>&2
    cp "$inpath" "$outdir/$outsubdir/$outfile"

    if test "$infile" != "$outfile"; then
        echo "Making a link from \"$outfile\" to the original name \"$infile\"." 1>&2
        ln -sf "$outfile" "$outdir/$outsubdir/$infile" 2>/dev/null
    fi

    echo "Now building the database for \"$outfile\"." 1>&2
    cd "$outdir/$outsubdir"
    "$builder" "$outfile" 1>&2
)

# if building failed, then output an error message and clean up anything partially written.
if [ $? -gt 0 ]; then
    echo "Unable to build database for file: \"$outdir/$outsubdir/$outfile\"." 1>&2

    for file in "$outdir/$outsubdir/$outfile" "$outdir/$outsubdir/$infile"; do
        echo "Cleaning file \"$file\" due to build failure." 1>&2
        rm -f "$file" 2>&2
    done

    echo "Cleaning path \"$outdir/$outsubdir\" due to build failure." 1>&2
    cd "$outdir" && rmdir -p "$outsubdir" 1>&2
    exit 1
fi

echo "Done!" 1>&2

echo "$outdir/$outsubdir/$outfile"

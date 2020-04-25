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

# figure out path to store pe into
echo "Attempting to determine versioning info for \"$inpath\"." 1>&2
outpath=`"$PYTHON" "$SYRINGE/tools/peversionpath.py" "$@" "$inpath" 2>/dev/null`
if test "$?" -gt 0; then
    echo "Unable to format versioning info for \"$infile\" using default format." 1>&2
    formats="/{FileVersion}/{OriginalFilename} /{FileVersion}/{InternalName} /{FileVersion}/{__name__} /{ProductVersion}/{OriginalFilename} /{ProductVersion}/{InternalName} /{ProductVersion}/{__name__}"
    for fmt in $formats; do
        echo "Re-attempting with another format : $fmt" 1>&2
        outpath=`"$PYTHON" "$SYRINGE/tools/peversionpath.py" -f "{__name__}$fmt" "$@" "$inpath" 2>/dev/null`
        test "$?" -eq "0" && break
        outpath=
    done

    if test -z "$outpath"; then
        echo "Unable to determine the path from the VERSION_INFO record : $inpath" 1>&2
        seconds=`stat -c %W "$inpath"`
        ts=`date --utc --date=@$seconds +%04Y%02m%02d.%02H%02M%02S`
        outpath="$infile/$ts/$infile"
        echo "Falling back to creation timestamp ($ts) for $inpath" 1>&2
    fi
fi
echo "Output path determined from version was \"$outpath\"." 1>&2

outsubdir=`dirname "$outpath"`
outfile=`basename "$outpath"`

if [ -d "$outdir/$outsubdir" -a -f "$outdir/$outsubdir/$outfile" ]; then
    echo "Output path \"$outdir/$outsubdir\" and it's file \"$outdir/$outsubdir/$outfile\" already exists." 1>&2
    echo "$outdir/$outsubdir/$outfile"
    exit 0
fi

echo "Attempting to determine the machine type for \"$inpath\"" 1>&2
machine=`"$PYTHON" "$SYRINGE/tools/pe.py" -p --path 'FileHeader:Machine' "$inpath" 2>/dev/null`
if test "$?" -gt 0; then
    echo "Error trying to parse PE file : $inpath" 1>&2
    exit 1
fi
echo "The PE machine type was determined as #$machine." 1>&2

case "$machine" in
    332) builder="build-idb.sh" ;;
    34404) builder="build-idb64.sh" ;;
    *) echo "Unsupported machine type : $inpath" 1>&2; exit 1 ;;
esac
echo "Decided on $builder to build the database." 1>&2

(
    echo "Carving a path to \"$outdir/$outsubdir/$outfile\"." 1>&2
    mkdir -p "$outdir/$outsubdir"

    echo "Dropping \"$inpath\" into \"$outdir/$outsubdir/$outfile\"." 1>&2
    cp "$inpath" "$outdir/$outsubdir/$outfile"

    if test "$infile" != "$outfile"; then
        echo "Making a link from \"$outfile\" to the original name \"$infile\"." 1>&2
        ln -sf `cygpath "$outdir/$outsubdir/$outfile"` "$outdir/$outsubdir/$infile" 2>/dev/null
    fi

    echo "Now building the database for \"$outfile\"." 1>&2
    cd "$outdir/$outsubdir"
    "$builder" "$outfile" 1>&2
)

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

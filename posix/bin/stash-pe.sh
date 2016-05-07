#!/bin/sh
inpath="$1"
outdir="$2"
infile=`basename "$inpath"`

PYTHON=`which python`
test "$SYRINGE" == "" && SYRINGE=`python -c 'print __import__("os").path.abspath(__import__("os").path.join(__import__("os").path.split(__import__("pecoff").__file__)[0], "..", ".."))'`

if test -z "$inpath" -o "$#" -ne 2; then
    echo "Usage: $0 file path" 1>&2
    echo "Stashes a PE file to specified directory keyed by it's version and then pre-build's an .idb" 1>&2
    exit 1
fi

if test ! -e "$SYRINGE/tools/pe.py" -o ! -e "$SYRINGE/tools/peversionpath.py"; then
    echo "Unable to locate tools (pe.py, peversionpath.py) for parsing the portable executable format : $SYRINGE" 1>&2
    exit 1
fi

if test ! -d "$outdir"; then
    echo "Specified path '$outdir' not found or is not a directory" 1>&2
    exit 1
fi

# figure out path (FIXME: if peversionpath.py errors-out, handle it properly instead of depending on dirname to return ./)
outpath=`"$PYTHON" "$SYRINGE/tools/peversionpath.py" "$inpath"`
if test "$?" -gt 0; then
    outpath="$outdir"
    echo "Unable to determine the path from the VERSION_INFO record : $inpath" 1>&2
fi

outsubdir=`dirname "$outpath"`
outfile=`basename "$outpath"`

machine=`"$PYTHON" "$SYRINGE/tools/pe.py" -p --path 'FileHeader:Machine' "$inpath"`
if test "$?" -gt 0; then
    echo "Error trying to parse PE file : $inpath" 1>&2
    exit 1
fi

case "$machine" in
    332) builder="build-idb.sh" ;;
    34404) builder="build-idb64.sh" ;;
    *) echo "Unsupported machine type : $inpath" 1>&2; exit 1 ;;
esac

(
mkdir -p "$outdir/$outsubdir"
cp "$inpath" "$outdir/$outsubdir/$outfile"
if test "$infile" != "$outfile"; then
    ln -sf `cygpath "$outdir/$outsubdir/$outfile"` "$outdir/$outsubdir/$infile"
fi

# build .idb based on version
    cd "$outdir/$outsubdir"
    sh "$builder" "$outfile"
)

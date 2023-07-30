#!/bin/sh
posix=ffmpeg
windows=ffmpeg.exe

case "$platform" in
    msys|cygwin)
        prog=`[ -x "$windows" ] && echo "$windows"`
        ;;
esac

if [ -z "$prog" ]; then
    argv0=`readlink -f "$0"`
    IFS=:
    for p in $PATH; do
        rp=`readlink -f "$p/$posix"`
        [ -x "$rp" ] && [ ! -d "$rp" ] && [ `stat -f%i "$argv0" 2>/dev/null || echo "$argv0"` != `stat -f%i "$rp" 2>/dev/null || echo "$rp"` ] && prog="$rp"
    done
    unset IFS
fi

[ -z "$prog" ] && echo "Unable to locate binary for program: $posix" 1>&2 && exit 1

inargs=()
while [ $# -gt 0 ]; do
    case "$1" in
        -i)
            inargs=("${inargs[@]}" "$1" "$2")
            shift 2
            break
            ;;
        *)
            inargs=("${inargs[@]}" "$1")
            shift 1
            ;;
    esac
done

outargs=(
    '-qscale:v' '31'                        # best quality
    '-filter:v' 'select=eq(pict_type\,I)'   # keyframes
    '-fps_mode:v' 'passthrough'             # include all frames
)

exec "$prog" "${inargs[@]}" "${outargs[@]}" "$@"
exit $?

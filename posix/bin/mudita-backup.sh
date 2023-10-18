#!/bin/sh
BS=16

# Mudita's culled password "scheme" is pretty fucking stupid.
password()
{
    printf '%s' "$1" | openssl dgst -r -sha256 -binary | openssl enc -base64 | dd bs="$BS" count=2 status=none
}

# Mudita-Center stacks the IV they use for encryption on top of the encrypted data.
decrypt()
{
    if [ ! -e "$1" ]; then printf 1>&2 '%s\n' "parameter 1: missing input file"; return 1; fi
    if [   -z "$2" ]; then printf 1>&2 '%s\n' "parameter 2: missing secret"; return 1; fi

    # IV
    dd skip=0 count=1 bs=$BS if="$1" status=none of="$1.IV"

    # Data
    dd skip=1 bs=$BS if="$1" status=none of="$1.DATA"

    # Secret
    password "$2" > "$1.SECRET"

    decrypt_components "$1"
}

decrypt_components()
{
    if [ ! -e "$1.IV" ] || [ ! -e "$1.SECRET" ] || [ ! -e "$1.DATA" ]; then printf 1>&2 '%s\n' "parameter 1: missing input file"; return 1; fi
    read IV < <( tohex <"$1.IV" )
    read SECRET < <( tohex <"$1.SECRET" )
    openssl enc -aes-256-ctr -d -iv "$IV" -K "$SECRET" -in "$1.DATA"
}

encrypt()
{
    if [ ! -e "$1" ]; then printf 1>&2 '%s\n' "parameter 1: missing file"; return 1; fi
    if [   -z "$2" ]; then printf 1>&2 '%s\n' "parameter 2: missing secret"; return 1; fi
    read IV < <( dd if=/dev/random count=1 bs=$BS | tee "$1.IV" | tohex )
    read SECRET < <( password "$2" | tee "$1.SECRET" | tohex )
    openssl enc -aes-256-ctr -iv "$IV" -K "$SECRET" -in "$1" -out "$1.DATA"
    cat "$1.IV" "$1.DATA"
}

tohex()
{
    od -A none -t x1 | tr -d $'\n '
    printf '\n'
}

usage()
{
    printf 1>&2 'Usage: %s [-d|-e] infile\n' "$1"
    printf 1>&2 '%s\n' 'Encrypts or decrypts a backup (tar) that is exported from the Mudita Center application.'
}

method=
infile=
while getopts d:e:h opt; do
    case "$opt" in
        h)
            method=u
            ;;
        e|d)
            [ ! -z "$method" ] && usage "$0" && exit 1
            method="$opt"
            infile=$OPTARG
            ;;
        \?)
            usage "$0"
            exit 1
    esac
done
shift $(( $OPTIND - 1 ))

rc=1
if [ -z "$method" ]; then
    printf 1>&2 'Error: Required parameter is missing\n'
    usage "$0"
    exit "$rc"
elif [ "$#" -ne 0 ]; then
    printf 1>&2 'Error: Invalid parameters were specified: %s\n' "$*"
    exit "$rc"
elif [ "$method" != 'u' ] && [ ! -e "$infile" ]; then
    printf 1>&2 'Error: File does not exist: %s\n' "$infile"
    exit "$rc"
fi

rc=1
[ -e "$infile.IV"       ] && printf 'Error: File already exists: %s\n' "$infile.IV" && exit $rc
[ -e "$infile.SECRET"   ] && printf 'Error: File already exists: %s\n' "$infile.SECRET" && exit $rc
[ -e "$infile.DATA"     ] && printf 'Error: File already exists: %s\n' "$infile.DATA" && exit $rc

rc=0
case "$method" in
    e)
        read -sp "Secret: " secret
        encrypt "$infile" "$secret"
        ;;

    d)
        read -sp "Secret: " secret
        decrypt "$infile" "$secret"
        ;;

    u)
        usage "$0"
        ;;
esac

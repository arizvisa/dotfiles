#!/bin/sh

# Terminology:
#   target -- the file that is supposed to be built
#   rule -- the function that is used to produce the target
#   deps -- any files that the rule uses to build a target

# Commands:
#   resolve $target $rule deps.. -- generates a tangible file $target
#   define $target $rule args.. -- defines a target that will execute rule with the specified args
#   pseudo $pseudo-target deps.. -- creates a pseudo-target that build each dep
#   default $target -- starts building the specified target by default
#   alias $original targets.. -- will point each target to the original target

# deps can be prefixed with specific command characters.
#   resolve prog1.dll sharedobject prog1.obj lib1.obj +kernel32.lib +user32.lib
#   alias prog1.dll prog1.lib prog1.def prog1.manifest
#
#   resolve prog2.exe link prog2.obj prog1.lib +gdi32.lib
#
#   pseudo MakeConfig AskUserYN
#   alias MakeConfig config.h localconfig.h
#
#   pseudo BuildEverything verify prog2.exe prog1.dll %MakeConfig

debug()
{
    if test $DEBUG -gt 0; then
        echo "[debug] $@" 1>&2
    fi
}

info()
{
    echo "[info] $@" 1>&2
}

error()
{
    echo "[error] $@" 1>&2
}

fatal()
{
    echo "[fail] $@" 1>&2
    exit 1
}

# hashGet(hash, key)
# returns hash[key]
hashGet()
{
    hash=$1
    field=$2
    shift 2

    if test "$field" == ""; then
        return 1
    fi

    echo "$hash" | while read item; do      # XXX: new process
        key=$( echo "$item" | cut -d ':' -f 1 )
        value=$( echo "$item" | cut -d ':' -f 2- )
        if test "$key" = "$field"; then
            echo "$value"
            exit 1  # XXX: remember we're currently inside a subprocess
        fi
    done

    if test $? -gt 0; then
        return 0
    fi

    # failed
#    error "$field not in $hash"
    return 1
}

hashKeys()
{
    echo "$1" | while read item; do      # XXX: new process
        key=$( echo "$item" | cut -d ':' -f 1 )
        echo $key
    done
    return 0
}

# hashAdd(hash, key, value)
# returns hash with key:value added
hashAdd()
{
    local IFS="\n"
    argh=$1
    field=$2
    value=$3
    shift 3

    item="$field:$value"

    echo "$argh"
    echo "$item"

    return 0
}

# __template(rule, function, dependencies)
# returns a script that resolves "rule" utilizing function
__template()
{
    _rule_=$1
    _directory_=$( echo "$_rule_" | sed 's/[^/\]\+$//' )
    _function_=$2
    shift 2
    _dependencies_=$@

    ## template produces the following code
    # count = 0
    # for dep in (_dependencies_):
    #     if dep in $LIST.keys():
    #         res = update_dependency( dep )     # creates file $dep
    #         count += res
    #     elsif dep.age > rule.age:
    #         count += 1
    #
    # if count > 0:
    #     _function_( rule, _dependencies_ )
    #
    # return count

    cat <<EOF
count=0
for dep in $_dependencies_; do

    #echo ----------------------------------------------------------------------
    #echo [1] $_rule_: looking for \$dep
    #echo "\$LIST"
    function=\$( hashGet "\$LIST" "\$dep" )

    if test \$? -gt 0; then
        #echo [2] $_rule_: returned \$? -\> \$function
        ## not sure how to resolve it, so treat it as a file
        if test ! -e "\$dep"; then
            fatal "file \$dep not found"
        fi

        if test "\$dep" -nt "$_rule_"; then
            debug "\$dep newer than $_rule_"
            count=\$( expr \$count + 1 )
        else
            debug "\$dep is ok"
        fi
    else
        #echo [2] $_rule_: returned \$? -\> \$function
        ## attempt resolving it w/ a generated build script
        debug "resolving \$dep with \$dep.$BUILDSUFFIX"
        . "$BUILDDIR/\$dep.$BUILDSUFFIX"
        count=\$( expr \$count + \$? )
    fi
done

if test \$count -gt 0 -o ! -e "$_rule_" -o "\$FORCE" -gt 0; then
    function=\$( hashGet "\$LIST" "$_rule_" )
    info "updating $_rule_ via $function"

    \$function $_rule_ $_dependencies_

    if test \$? -ne 0; then
        fatal "unable to update $_rule"
    fi
    debug "successfully updated $_rule_"
else
    info "$_rule_ is up to date"
fi

debug "$_rule_ returned \$count modified files"
return \$count
EOF

    return 0
}

# builds the specified rule
resolve()
{
    rule=$1
    function=$2
    shift 2

    LIST=$( hashAdd "$LIST" "$rule" "$function" )

    ## if rule is in a subdirectory
    # FIXME: i'm a dick for testing for '/'s via sed and a strcmp
    __directory=$( echo "$rule" | sed 's/[^/\]\+$//' )

    if test "$__directory" != "$rule" -a ! -d "$BUILDDIR/$__directory"; then
        __directory=$( echo "$rule" | sed 's/[^/\]\+$//' )
        mkdir -p "$BUILDDIR/$__directory"
        info "creating workspace: $__directory"
    fi

    out=$( __template "$rule" "$function" $@ )
    echo "$out" >| "$BUILDDIR/$rule.$BUILDSUFFIX"
    chmod +x "$BUILDDIR/$rule.$BUILDSUFFIX"
}

# builds the specified rule
__define()
{
    _rule_=$1
    _directory_=$( echo "$_rule_" | sed 's/[^/\]\+$//' )
    _function_=$2
    shift 2
    _arguments_=$@

    cat <<EOF
info "executing $_rule_ via $_function_"
$_function_ $_arguments_
result=\$?
debug "$_rule_ returned \$result"
return \$result
EOF
}

# executes a specified command with the given arguments
define()
{
    rule=$1
    function=$2
    shift 2

    LIST=$( hashAdd "$LIST" "$rule" "$function" )

    __directory=$( echo "$rule" | sed 's/[^/\]\+$//' )

    if test "$__directory" != "$rule" -a ! -d "$BUILDDIR/$__directory"; then
        __directory=$( echo "$rule" | sed 's/[^/\]\+$//' )
        mkdir -p "$BUILDDIR/$__directory"
        info "creating workspace: $__directory"
    fi

    out=$( __define "$rule" "$function" $@ )
    echo "$out" >| "$BUILDDIR/$rule.$BUILDSUFFIX"
    chmod +x "$BUILDDIR/$rule.$BUILDSUFFIX"
}

__help()
{
    echo "Usage: $0 [options] target"
cat <<EOF
build target using the contents of "$FILE"

  -A            make all errors non-fatal
  -x dir        use dir ($BUILDDIR) for storing internal build scripts
  -C dir        change to directory
  -d            display debugging information
  -F file       use specified build file
  -f            force building the specified rule
  -j maxprocs   parallel building
  -q            question mode (1 on failure, 0 on success)
  -R            rebuild workspace

EOF
}

#########################
### main code starts here
# globals
LIST=""

BUILDSUFFIX="sh"    #XXX: this is platform dependant

# options
DEBUG=0
NOBITCH=0
QUESTION=0
JOBS=0
FORCE=0
FILE=./pbuild.list
BUILDDIR="./.pbuild"
ROOT=$(pwd)

# parse opts
while getopts AC:dF:ij:qhx:f opt; do
    case $opt in
        A)
            NOBITCH=1
            ;;

        d)
            DEBUG=1
            ;;

        q)
            QUESTION=1
            fatal "question-mode not supported"
            ;;

        x)
            BUILDDIR=$OPTARG
            ;;

        C)
            chdir $OPTARG       #XXX: chdir needs to be platform independant
            ;;

        F)
            FILE=$OPTARG
            ;;

        j)
            JOBS=$OPTARG
            fatal "parallel builds not supported"
            ;;

        h)
            __help $0
            exit 0
            ;;

        f)
            FORCE=1
            ;;

        *)
            exit 0
            ;;
    esac
done
shift $( expr $OPTIND - 1 )

if test $# -lt 1; then
    __help $0
    exit 0
fi

RULE="$1"
shift

if test -e "$BUILDDIR"; then
    if test ! -d "$BUILDDIR"; then
        fatal "$BUILDDIR is not a directory"
    fi
    debug "$BUILDDIR already exists"
else
    info "making build directory: $BUILDDIR"
    mkdir -p "$BUILDDIR"
fi

debug "processing $FILE"
. "$FILE" $@

if test ! -f "$BUILDDIR/$RULE.$BUILDSUFFIX"; then
    fatal "unknown target: $RULE"
fi

test "$FORCE" -gt 0 && info "user requested force build of $RULE"

# XXX: should dump all targets here and rm them if they're files
debug "building $RULE"
. "$BUILDDIR/$RULE.$BUILDSUFFIX"

info "successfully executed $RULE"

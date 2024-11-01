#!/usr/bin/env bash
# FIXME: This still needs some work to do.
# 1. There needs to be some way to include the "gtags_parser" languages in the
#    generated configuration.
# 1a. There's multiple libraries for parsing the same language. So, there needs
#     to be a way to prioritize which parser (universal-ctags, exuberant-ctags,
#     and pygments) to use for a specific language.
# 1b. There needs to be a way to list the language _and_ the supported parsers.
# 2. Should the language case matter, or should we make the effort to normalize
#    the case when checking? Personally, I dont think the case should matter...
ARG0=`realpath "$0"`

set -o nounset
set -o noclobber

GTAGS=`type -P gtags`
GLOBAL=`type -P global`
CSCOPE=`type -P cscope`
LOGNAME=`basename "$ARG0"`

# configuration
GTAGSLABEL=default
GTAGSPARAMETERS=( --accept-dotfiles --explain --verbose --warning )
CSCOPEPARAMETERS=( -b -q -v )
GTAGSPARAMETERS_QUIET=( --accept-dotfiles --warning )
CSCOPEPARAMETERS_QUIET=( -b -q )

# default file names
GTAGSCONF=.global.conf
GTAGSFILE=.global.files
GTAGSLOG=.global.log
GTAGSRC=.globalrc

CSCOPEFILE=cscope.files
CSCOPEOUT=cscope.out

usage()
{
    printf "usage: %s [-h] [-?] [-l] [-q] [-n] [-{o,O} output] [[-f language pattern]...] [[-X pattern]...] [[-x directory]...] directory1...\n" "$1"
    printf "builds a cscope database in each directory specified at the commandline.\n"
    printf "if a filter isn't specified, then use \"'*.c' '*.h' '*.cc' '*.cpp' '*.hpp'\".\n"
    printf "if \$CSPROG isn't defined, then use \"%s\" to build database.\n" "cscope -b -v -i-"
}

### general utilities
log()
{
    local fmt="$LOGNAME: $1"
    shift
    printf "$fmt" "$@" 1>&2
}

warn()
{
    log "$@"
}

get_system_directory()
{
    prefix=`dirname "$GTAGS" | xargs -I {} realpath --quiet -- {}/..`
    case "$1" in
        prefix)
            printf '%s\n' "$prefix"
            return 0
        ;;
        bindir)
            dirname "$GTAGS"
            return 0
        ;;
        includedir) suffix='/include' ;;
        datadir)    suffix='/share' ;;
        libexecdir) suffix='/libexec' ;;
        docdir)     suffix='/share/doc' ;;
        infodir)    suffix='/share/info' ;;
        localedir)  suffix='/share/locale' ;;
        localstatedir)
            realpath --quiet /var
            return 0
            ;;
        runstatedir)
            realpath --quiet /var/run
            return 0
            ;;
        sysconfdir) suffix='/etc' ;;
        *)
            warn 'unknown system directory type: %s\n' "$1" 1>&2
            exit 1
        ;;
    esac

    realpath --quiet --canonicalize-missing -- "$prefix$suffix"
}

get_configuration_directory()
{
    case "$1" in
        libexecdir|datadir|runstatedir|docdir)
            directory=`get_system_directory "$@"`
        ;;
        *)
            get_system_directory "$@"
            return $?
        ;;
    esac

    for path in /gtags /global; do
        if [ -d "$directory/$path" ]; then
            join_path_absolute "$directory" "$path"
            return 0
        fi
    done

    warn 'unable to locate %s directory in the determined path: %s\n' "$1" "$directory" 1>&2
    exit 1
}

# convert the parameter to a relative path
relative_to()
{
    realpath --zero --quiet --canonicalize-missing --relative-to="$output" -- "$@" | while read -d $'\0' rp; do
        # if an absolute or relative path, then print it as-is. otherwise, we
        # need to prefix the "./" in front of the path to force it as relative.
        case "$rp" in
            /*|./*) printf '%s\n' "$rp"     ;;
            *)      printf './%s\n' "$rp"   ;;
        esac
    done
}

join_path_absolute()
{
    joined="$1"
    shift
    for component in "$@"; do
        joined+="/$component"
    done
    realpath --quiet --canonicalize-missing -- "$joined"
}

build_language_index_from_filters()
{
    local -n language_map="$1"
    shift

    let index=0
    for filter in "$@"; do
        IFS=' ' read language filter <<<"$filter"
        language_map["$language"]+=":$index"
        let index++
    done
}

format_language_index_for_builder()
{
    local -n language_map="$1"
    shift
    local -a options=( "$@" )
    for language in "${!language_map[@]}"; do
        IFS=: read _ rest <<<"${language_map[$language]}"
        IFS=: read -a indices <<<"$rest"

        local -a filters=()
        for index in "${indices[@]}"; do
            IFS=' ' read _ filter <<<"${options[$index]}"
            filters+=( "$filter" )
        done

        printf '%s\n' "$language"
        printf "%s\n" "${filters[@]}"
        printf '\0'
    done
}

extract_patterns_from_language_index()
{
    local -n language_map="$1"
    shift
    local -a options=( "$@" )
    for language in "${!language_map[@]}"; do
        IFS=: read _ rest <<<"${language_map[$language]}"
        IFS=: read -a indices <<<"$rest"
        local -a filters=()
        for index in "${indices[@]}"; do
            IFS=' ' read _ filter <<<"${options[$index]}"
            filters+=( "$filter" )
        done
        printf '%s\0' "${filters[@]}"
    done
}

### command-specific utilities
global_configuration_file()
{
    get_configuration_directory datadir | xargs -I {} printf '%s/%s\0' {} 'gtags.conf' | xargs -0 realpath --
}

# remove comments and strip spaces from a configuration in stdin
global_configuration_squeeze()
{
    gawk '!/^[[:blank:]]*#/' | perl -pe 's/\s*\\\n//g' | perl -pe 's/:[[:space:]]:/::/g'
}

# return all of the available labels from a configuration in stdin
global_configuration_labels()
{
    global_configuration_squeeze | cut -d':' -f1 | cut -d'|' -f1 | gawk NF
}

# extract a specific variable from a configuration in stdin
global_configuration_extract()
{
    variable="$1"
    read definition < <( printf '%s=' "$variable" )
    #global_configuration_squeeze | perl -pe 's/(?<!\\):/:\n/g' | grep -e "^$definition" | sed "s/$definition/\n$definition/g"
    global_configuration_squeeze | perl -pe 's/(?<!\\):/:\n/g' | perl -pe "s/\<$definition\>/\n$definition/g"
}

# process a configuration as stdin and filter out all the "langmap" languages
global_configuration_langmap_languages()
{
    global_configuration_extract 'langmap' \
        | grep -e '^langmap=' \
        | sed 's/,/\n/g' \
        | gawk -F '\\\\:' 'NF {print $1}' \
        | sed 's/^langmap=//' \
        | sort -u
}

# process a configuration as stdin and filter out all the "gtags_parser" languages
global_configuration_plugin_languages()
{
    global_configuration_extract 'gtags_parser' \
        | grep -e '^gtags_parser=' \
        | sed 's/^gtags_parser=//' \
        | gawk -F '\\\\:' 'NF {print $1}' \
        | sort -u
}

# read language map from default configuration
global_langmap()
{
    "$csprog" --config=langmap "$@" | while read -d, item; do
        IFS=: read language extensions <<< "$item"
        printf '%s\t%s\n' "$language" "$extensions"
    done
}

global_gtags_parser()
{
    "$csprog" --config=gtags_parser "$@" | while read -d, item; do
        IFS=: read language parser_library <<< "$item"
        printf '%s\t%s\n' "$language" "$parser_library"
    done
}

# read skip patterns from default configuration
global_skip()
{
    "$csprog" --config=skip "$@" | while read -d, item; do
        printf '%s\n' "$item"
    done
}

tc_build_label()
{
    label="$1"
    shift
    printf '%s:' "$label"
    printf ':%s' "$@"
    printf ':\n'
}

tc_build_skip()
{
    label="$1"
    shift
    printf '%s:' "$label"
    printf ':skip='
    printf '%s\0' "$@" | paste -zsd, - | xargs -0 printf "%s:\n"
}

tc_build_langmap_content_entry()
{
    printf '%s\n' ':langmap=\'
}

tc_build_langmap_content_continue()
{
    printf '%s\n' ',\'
}

tc_build_langmap_content_exit()
{
    printf '%s\n' '\'
}

tc_build_langmap_content_text()
{
    language="$1"
    shift
    printf '%s\:' "$language"
    xargs -0 printf '%s'
}

tc_build_langmap_content_pattern()
{
    language="$1"
    shift
    printf '%s\:' "$language"
    xargs -0 printf '(%s)'
}

tc_build_empty_header()
{
    label="$1"
    shift
    printf '%s:%s\n\t%s\n' "$label" '\' '::'
}

tc_build_langmap_header()
{
    label="$1"
    shift
    printf '%s:\\\n\t' "$label"
}

tc_build_langmap_footer()
{
    label="$1"
    shift
    printf '%s\n' ':'
}

global_langmap_extensions()
{
    local -A default_langmap
    while read language extensions; do
        default_langmap[$language]+="$extensions"
    done < <( global_langmap )
    local -p default_langmap
}

tc_build_langmap_defaults()
{
    name="$1"
    eval `global_langmap_extensions`
    tc_build_langmap_header "$name"
    tc_build_langmap_content_entry

    count=1
    total="${#default_langmap[@]}"
    for lang in "${!default_langmap[@]}"; do
        exts="${default_langmap[$lang]}"
        printf '%s\0' "$exts" | tc_build_langmap_content_text "$lang"
        [ "$count" -lt "$total" ] && tc_build_langmap_content_continue
        count=`expr $count + 1`
    done
    [ "$total" -gt 0 ] && tc_build_langmap_content_exit
    tc_build_langmap_footer "$name"
}

# XXX: i think i was testing adding support for arbitrary languages here
global_build_gtagsconf()
{
    number="$1"
    shift
    local -a ignored=( "$@" )

    # figure out all of the definition entries and convert them to labels.
    # if $HOME/$GTAGSRC exists, then ensure that file also gets included.
    local -a entries=( general ignore include )
    if [ ! -z "${HOME}" ] && [ -e "${HOME}/${GTAGSRC}" ]; then entries+=( "${GTAGSLABEL}"@"~/${GTAGSRC}" ); fi
    local -a labels=()
    for entry in "${entries[@]}"; do labels+=( "tc=$entry" ); done

    # output all of the labels that we determined.
    tc_build_label "${GTAGSLABEL}" "${labels[@]}"
    tc_build_skip "ignore" "GPATH" "GRTAGS" "GTAGS" "${ignored[@]}"

    #printf "%s\0" '*.cc' '*.cpp' '*.x' '' 1>&3
    #tc_build_langmap "include" 'cpp' $'*.c\0*.cc\0*.cc' #'php' $'*.php\n*.php3' "c\n*.c\n*.h\n'

    tc_build_langmap_defaults "general"

    if [ "$number" -gt 0 ]; then
        tc_build_langmap_header 'include'
        tc_build_langmap_content_entry

        count=1
        while read -d $'\0' language filters; do
            printf '%s\0' $filters | tc_build_langmap_content_pattern "$language"
            [ "$count" -lt "$number" ] && tc_build_langmap_content_continue
            count=`expr "$count" + 1`
        done
        tc_build_langmap_content_exit
        tc_build_langmap_footer 'include'
    else
        tc_build_empty_header 'include'
    fi
}

get_find_expressions_for_patterns()
{
    local -n exclude="$1"
    shift

    local -a exclude_parameters=()
    for directory in "${exclude[@]}"; do
        relative=`relative_to "${directory}"`
        case "${relative}" in
            */\*)
                exclude_parameters+=( '-o' -path "${relative}" )
            ;;
            *)
                exclude_parameters+=( '-o' -path "${relative}" )
                exclude_parameters+=( '-o' -path "${relative}/*" )
            ;;
        esac
    done

    local -a parameters=()
    while read -d $'\0' pattern; do
        parameters+=( '-o' -type "f" -name "${pattern}" )
    done

    local -a patterns=()
    let stop=( "${#parameters[@]}" - 1 )
    for index in `seq 1 $stop`; do
        patterns+=( "${parameters[$index]}" )
    done

    local -a exclusions=()
    let stop=( "${#exclude_parameters[@]}" - 1 )
    for index in `seq 1 $stop`; do
        exclusions+=( "${exclude_parameters[$index]}" )
    done

    # output parameters for excluding directories (really, paths)
    if [ "${#exclusions[@]}" -gt 0 ]; then
        printf '%s\0' \( \! \( "${exclusions[@]}" \) \)
    else
        printf '%s\0' '-true'
    fi

    # now we include all of our patterns
    printf '%s\0' '-a'
    if [ "${#patterns[@]}" -gt 0 ]; then
        printf '%s\0' '(' "${patterns[@]}" ')'
    else
        printf '%s\0' '-true'
    fi

    # then we can include any extra parameters (actions)
    printf '%s\0' "$@"
}

cscope_escape()
{
    sed 's/\(["\\]\)/\\\1/g'
}

### command-detection utilities
choose_command()
{
    program="$1"
    path="$2"
    case "$program" in
    cscope|cscope.*)
        symbol="cscope"
        ;;
    gtags|gtags.*)
        symbol="global"
        ;;
    *)
        warn 'unsupported tag program was specified : %s\n' "$path" 1>&2
        exit 1
    esac
    printf '%s\n' "$symbol"
}

cscope_description()
{
    printf '%s\n' "cscope"
}
global_description()
{
    printf '%s\n' "gnu global"
}

### define explicit commands that the user can use via the parameters

## list the available languages that the user is allowed to map globs to
global_list_languages()
{
    read configuration < <( get_configuration_directory datadir | xargs -I {} printf '%s/%s\0' {} 'gtags.conf' | xargs -0 realpath -- )
    configuration_parameters=( --gtagsconf "${configuration}" )

    local -A languages
    while read label; do

        # add languages and patterns to our associative array.
        # FIXME: we should probably do a better job of removing duplicates.
        while read language pattern; do
            if [ "${languages[$language]+exists}" != 'exists' ]; then
                languages["$language"]="$pattern"

            # if the pattern is different from what was stored in our associative
            # array, then go ahead and append the pattern to our current value.
            elif [ "${languages[$language]}" != "$pattern" ]; then
                local old="${languages[$language]}"
                languages["$language"]="$old,$pattern"

            # otherwise, this pattern was already added to the specified language.
            else
                local old="${languages[$language]}"
                [ "$pattern" == "$old" ]
            fi
        done < <( global_langmap "${configuration_parameters[@]}" --gtagslabel="$label" )

        # now we add all the languages listed by the parsers
        while read language library; do
            if [ "${languages[$language]+exists}" != 'exists' ]; then
                languages["$language"]+="($library)"
            fi
        done < <( global_gtags_parser "${configuration_parameters[@]}" --gtagslabel="$label" )
    done < <(global_configuration_labels <"${configuration}")

    for language in "${!languages[@]}"; do
        printf '%s\t%s\n' "$language" "${languages[$language]}"
    done | sort -u | expand -t 24,70
}

global_list_parsers()
{
    read configuration < <( get_configuration_directory datadir | xargs -I {} printf '%s/%s\0' {} 'gtags.conf' | xargs -0 realpath -- )
    configuration_parameters=( --gtagsconf "${configuration}" )

    local -A languages
    while read label; do

        # add all the languages listed by the parsers
        while read language library; do
            if [ "${languages[$language]+exists}" != 'exists' ]; then
                languages["$language"]="$library"
            else
                log 'duplicate language library for %s: %s\n' "$language" "$library"
                languages["$language"]+=":$library"
            fi
        done < <( global_gtags_parser "${configuration_parameters[@]}" --gtagslabel="$label" )
    done < <(global_configuration_labels <"${configuration}")

    # output every parser that we collected and trim off the trailing ':'.
    for language in "${!languages[@]}"; do
        read unique < <( tr ':\n' '\0' <<< "${languages[$language]}" | xargs -0 printf '%s\n' | sort -u | tr '\n' ':' | sed 's/:$//' )
        printf '%s\t%s\n' "$language" "$unique"
    done | sort -u | expand -t 24,70
}

cscope_list_languages()
{
    # we hardcode cscope's supported languages.
    printf '%s\t%s\n' C .c.h Flex .l YACC .y \
        | sort -u | expand -t 24,70
}

## build the database for each tag program type
global_build_database()
{
    local output="$1"
    local -n filters="$2"
    local -n excluded="$3"
    local -n ignored="$4"
    shift 4

    log 'using %s to build database\n' "$description"

    # build an index for each language referencing the opt_filter
    local -A language_filter
    build_language_index_from_filters language_filter "${filters[@]}"

    # now we need to feed each language and pattern to
    # our langmap builder for the gtags configuration.
    if [ ! -e "${output}/$GTAGSCONF" ] || [ "${opt_clobber}" -gt 0 ]; then
        number="${#language_filter[@]}"
        format_language_index_for_builder language_filter "${filters[@]}" \
            | global_build_gtagsconf "$number" "${ignored[@]}" \
        >| "${output}/$GTAGSCONF"
        log 'wrote configuration file: %s\n' "${output}/$GTAGSCONF"
    else
        log 'reusing configuration file: %s\n' "${output}/$GTAGSCONF"
    fi

    # use find(1) to determine all of the matching paths
    # for the specified filters.
    if [ ! -e "${output}/$GTAGSFILE" ] || [ "${opt_clobber}" -gt 0 ]; then
        extract_patterns_from_language_index language_filter "${filters[@]}" \
            | get_find_expressions_for_patterns excluded -print \
            | xargs -0 find "${directories[@]}" \
        >| "${output}/$GTAGSFILE"

        read -d' ' count < <( wc -l "${output}/$GTAGSFILE" )
        log 'wrote %d names to file listing: %s\n' "$count" "${output}/$GTAGSFILE"
    else
        read -d' ' count < <( wc -l "${output}/$GTAGSFILE" )
        log 'reusing %d names from file listing: %s\n' "$count" "${output}/$GTAGSFILE"
    fi

    # collect our desired parameters.
    local -a parameters=()
    parameters+=( --gtagsconf "${output}/$GTAGSCONF" )
    parameters+=( --gtagslabel "$GTAGSLABEL" )
    parameters+=( --objdir "${output}" )
    parameters+=( --file "${output}/$GTAGSFILE" )

    # now we just need to use cscope to build the database.
    log 'building %s database with: %s\n' "$description" "\"${GTAGS}\" ${GTAGSPARAMETERS[*]} ${parameters[*]} $*"
    "${GTAGS}" "${GTAGSPARAMETERS[@]}" "${parameters[@]}" "$@"
}

cscope_build_database()
{
    local output="$1"
    local -n filters="$2"
    local -n excluded="$3"
    local -n ignored="$4"
    shift 4

    log 'using %s to build database.\n' "$description"

    # build an index for each language referencing the opt_filter
    local -A language_filter
    build_language_index_from_filters language_filter "${filters[@]}"

    # go through and find all the files that were requested.
    if [ ! -e "${output}/$CSCOPEFILE" ] || [ "${opt_clobber}" -gt 0 ]; then
        extract_patterns_from_language_index language_filter "${filters[@]}" \
            | get_find_expressions_for_patterns excluded -print \
            | xargs -0 find "${directories[@]}" \
            | while read filename; do

            # if there's spaces, then we need to quote and escape the filename.
            if grep -qoe '[[:space:]]' <<< "$filename"; then
                printf '%s\0' "$filename" | cscope_escape | xargs -0 printf '"%s"\n'
            else
                printf '%s\n' "$filename"
            fi
        done >| "${output}/$CSCOPEFILE"

        if [ "$?" -eq 0 ]; then
            read -d' ' count < <( wc -l "${output}/$CSCOPEFILE" )
            log 'wrote %d names to file listing: %s\n' "$count" "${output}/$CSCOPEFILE"
        else
            fatal 13 'unable to write to file listing: %s\n' "${output}/$CSCOPEFILE"
        fi
    else
        read -d' ' count < <( wc -l "${output}/$CSCOPEFILE" )
        log 'reusing %d names from file listing: %s\n' "$count" "${output}/$CSCOPEFILE"
    fi

    # FIXME: need to use the ignored parameter to filter the list of files

    # now we just need to use cscope to build the database.
    log 'building %s database with: %s\n' "$description" "\"${CSCOPE}\" -f \"${output}/$CSCOPEOUT\" -i \"${output}/$CSCOPEFILE\" ${CSCOPEPARAMETERS[*]} $*"
    "${CSCOPE}" -f "${output}/$CSCOPEOUT" -i "${output}/$CSCOPEFILE" "${CSCOPEPARAMETERS[@]}" "$@"
}

### now we can begin the actual logic of the script that figures out what
### the user is trying to do and how we'll need to do it.

## first we need to figure out which program we need to use for making tags
if [ -z "${CSPROG:-}" ]; then
    CSPROG=`type -P "$GTAGS" || type -P "$CSCOPE"`
fi
csprog=`basename "$CSPROG"`
cmd=`choose_command "$csprog" "$CSPROG"`
if [ "$?" -gt 0 ]; then
    warn 'unable to find a valid command (%s) for building index\n' 'cscope or gnu global'
    exit 2
fi

# assign some variables to help with emitting error and status messages
description=`eval $cmd\_description`

## now we can process our command line parameters
declare -a opt_filters
declare -a opt_ignore
declare -a opt_exclude
declare -a opt_output
declare -i opt_clobber=1

rp=`realpath "$ARG0"`
operation=build_database

while getopts hglf:X:x:o:qO: opt; do
    case "$opt" in
        h|\?)
            usage "$ARG0"
            exit 0
            ;;
        q)
            GTAGSPARAMETERS=( ${GTAGSPARAMETERS_QUIET[@]} )
            CSCOPEPARAMETERS=( ${CSCOPEPARAMETERS_QUIET[@]} )
            ;;
        O)
            opt_output="$OPTARG"
            GTAGSFILE="${GTAGSFILE#.}"
            GTAGSCONF="${GTAGSCONF#.}"
            let opt_clobber=1
        ;;
        o)
            opt_output="$OPTARG"
            GTAGSFILE="${GTAGSFILE#.}"
            GTAGSCONF="${GTAGSCONF#.}"
            let opt_clobber=0
            ;;
        g)
            operation=list_parsers
            ;;
        l)
            operation=list_languages
            ;;
        x)
            opt_exclude+=( "$OPTARG" )
            log 'excluding directory : %s\n' "$OPTARG"
            ;;
        X)
            opt_ignore+=( "$OPTARG" )
            log 'ignoring pattern : %s\n' "$OPTARG"
            ;;
        f)
            language="$OPTARG"
            if [ ${OPTIND} -le $# ]; then
                filter=${!OPTIND}
                let OPTIND++
            else
                log 'missing filter for language parameter : -f %s\n' "$language"
                exit 1
            fi
            log 'adding language filter : %s : %s\n' "$language" "$filter"
            opt_filters+=( "$language $filter" )
            ;;
    esac
done
shift `expr "$OPTIND" - 1`

# assign the variables we're going to use.
if [ -z "${opt_output:-}" ]; then
    output=`realpath -qe .`
else
    output=`realpath -qe "${opt_output}"`
fi
if [ -z "${output}" ] || [ ! -d "${output}" ]; then
    read target < <( [ -z "${output}" ] && echo . || echo "${output}" )
    warn 'the requested output directory does not exist: %s\n' "${target}"
    exit 1
else
    log 'writing database to directory : %s\n' "${output}"
fi

declare -a directories
if [ "$#" -gt 0 ]; then
    directories=( "$@" )
else
    directories=( '.' )
fi
log 'searching under directory: %s\n' "${directories[@]}"

full_operation="${cmd}_${operation}"
log 'performing operation: %s\n' "${full_operation}"

export output opt_clobber
"${cmd}_${operation}" "${output}" opt_filters opt_exclude opt_ignore
exit $?

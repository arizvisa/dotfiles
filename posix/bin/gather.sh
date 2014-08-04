#!/bin/sh
## functions
halp()
{
	argv0=$1

	cat 1>&2 <<EOF
Usage: $argv0 [-d] [-v] [-q] [-i] [-o file] files..
Description: concatenate all files into an output file
Options:
  -h,--help    Display this information
  -d           Delete files used after creating output file
  -v           Enable verbose logging
  -q           Run quietly/Disable logging
  -o file      Write concatenated files to file instead of /dev/stdout
  -i           Prepend output with concatenated files
EOF
}

grope() {
    file -b -h --mime-type "$*"
}
logerror() {
	echo "Error: $*" 1>&2
}
log() { 
	[ $flag_silent -eq 0 ] && echo "Status: $*" 1>&2
}
logverbose() {
	[ $flag_silent -eq 0 ] && [ $flag_verbose -eq 1 ] && echo "Status: $*" 1>&2
}
insert() {
	echo -e "0r $2\nw" | ed "$1" 2>/dev/null
}
append() {
	cat "$2" >> "$1"
}

## parsing options
argv0=$0
args=$(getopt hqvdio: $*)
if [ "$?" -ne 0 -o "$#" -eq 0 ]; then
	logerror "Invalid command-line arguments"
	halp "$argv0"
	exit 1
fi

output=/dev/stdout
flag_silent=0
flag_verbose=0
flag_oktodelete=0
flag_insert=0

set -- $args
while [ $# -gt 0 ]; do
	case "$1" in 
		-h)
			halp $argv0;
			exit 0
		;;
		-o)
			output=$2;
			shift 2;
		;;
		-q) flag_silent=1; shift;;
		-v) flag_verbose=1; shift;;
		-d) flag_oktodelete=1; shift;;
		-i) flag_insert=1; shift;;
		--) shift; break;;
	esac
done

if [ -f "$output" ]; then
    temporary=$(basename "$output.$$")
else
    temporary="$output"
fi

## concatenating files
files=$( for glob in $@; do
	for p in $glob; do
		find $(dirname $p) -maxdepth 1 -type f -name $(basename $p)
	done
done | sort -r -n )

count=$(echo "$files" | wc -l | sed 's/ //g')
logverbose "adding $count files into file \"$temporary\".."

echo "$files" | while read x; do
	type=$(grope "$x")
	if [ "$type" = "application/x-gzip" ]; then
		zcat "$x" >> "$temporary"
	elif [ "$type" = "application/x-bzip2" ]; then
		bzcat "$x" >> "$temporary"
	elif [ "$type" = "text/plain" ]; then
		cat "$x" >> "$temporary"
	fi
	log "$x : $type"
done

if [ "$flag_insert" -eq 1 ]; then
	logverbose "inserting \"$temporary\" in front of \"$output\""
	insert "$output" "$temporary"
else
    logverbose "appending results to $output"
    append "$output" "$temporary"
fi

if [ -f "$temporary" ]; then
    rm -f "$temporary"
fi

if [ "$flag_oktodelete" -eq 1 ]; then
	count=$( echo "$files" | wc -l | sed 's/ //g' )
	if [ -c "$output" ]; then
		logerror "refusing to delete $count files. please specify -o to store the output before removing files"
		exit 1
	fi
	logverbose "removing $count files.."
	echo "$files" | while read x; do
		logverbose "    $x"
		rm -f "$x"
	done
fi

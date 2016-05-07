#!/bin/bash
# stolen and modified from http://bashcurescancer.com/media/scripts/monitorCpuUsage.sh.txt

usageHelp="Usage: ${0##*/}"
uidHelp="-u starting uid, must be an integer greater than or equal to 0 (only used with \"-w users\")"
watchHelp="-w what to watch, must be \"users\" or \"procs\""
debugHelp="-d specifies debug mode in which -e, and -u do not need to be specified."
badOptionHelp="Option not recognised"
printHelpAndExit()
{
	echo "$usageHelp"
	echo "$uidHelp"
	echo "$watchHelp"
	echo "$debugHelp"
	exit $1
}
printErrorHelpAndExit()
{
        echo
        echo "$@"
        echo
        echo
        printHelpAndExit 1
}
whatTowatch=""
startAtUid="-1"
debug=""
while getopts "hw:e:u:m:d" optionName; do
	case "$optionName" in
		h)	printHelpAndExit 0;;
		d)	debug="0";;
		w)	whatTowatch="$OPTARG";;
		u)	startAtUid="$OPTARG";;
		[?])	printErrorHelpAndExit "$badOptionHelp";;
	esac
done
usersToWatch()
{
	awk -F: '{print $1 , $3}' /etc/passwd | \
	while read user id
	do
		if [ $id -ge $startAtUid ]
		then
			echo $user
		fi
	done
}
sum()
{
	local cum=0
	for i in $@
	do
		(( cum = cum + ${i%.*} ))
	done
	echo $cum
}
abusersExist()
{
	if [[ "$whatTowatch" == "users" ]]
	then
		for user in $( usersToWatch )
		do
			cpu=$( ps -o pcpu -u $user | grep -v CPU )
			local cumUsage=$( sum $cpu )
			echo "$user	$cumUsage%"
		done
	elif [[ "$whatTowatch" == "procs" ]]
	then
		local last=""
		local cumUsage=0
		ps -o pid,comm,pcpu -e | grep -v CPU | sort | \
		while read pid comm cpu
		do
			if [[ "$comm" != "$last" ]] && [[ ! -z "$last" ]]
			then
                echo "$pid	$last	$cumUsage%"
				cumUsage=0
			fi
			cumUsage=$( sum $cumUsage $cpu )
			last="$comm"
		done
	fi
}
abusersExist

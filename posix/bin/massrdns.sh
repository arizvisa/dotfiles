#!/bin/sh
count=2

rdnsify()
{
    echo $1 | perl -e '$_=<>;chomp; @_=split(/\./, $_); print sprintf("%s.in-addr.arpa\n", join(".",reverse @_));'
}

# spawns count * 6 processes
multirdns()
{
    for i in $( yes | head -n $count ); do
        read host
        if [ -z $host ]; then
            wait
            return 1
        fi
        echo $host '	' $( dig +noall +answer ptr $( rdnsify $host ) ) &
    done
    wait
    return 0
}

while [ $? -eq 0 ]; do
    multirdns
done


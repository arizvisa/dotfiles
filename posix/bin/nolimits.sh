#!/bin/sh
filter()
{
    ssam -e $'x/\(/ i/\t/' | ssam -e $'x/\)/ a/\t/' | cut -f2 | ssam -e 'x/^\(.*/ g/\(-/ x/\(/ c/,/' | cut -d, -f2 | cut -d')' -f1 | sed 's/ //g'
}

ulimit -Ha | filter | xargs printf "ulimit -H %s unlimited\n"
ulimit -Sa | filter | xargs printf "ulimit -H %s unlimited\n"

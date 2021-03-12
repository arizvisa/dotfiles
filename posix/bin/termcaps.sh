#!/bin/sh
infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read n; do
  comment=`man -w 5 terminfo | xargs zcat | egrep -A 2 "\b$n[^[:print:]]" | tr -d '\n' | sed 's/T{/{/g;s/T}/}/g' | egrep -m1 -o '\{[^}]+\}' | tr -d '\n'`
  printf "%s -- %s\n" "$n" "$comment"
done

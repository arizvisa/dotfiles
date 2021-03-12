#!/bin/sh
infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read capability; do
  comment=`man -w 5 terminfo | xargs zcat | ssam -e 'x/T{/ .,/T}/ x/\n/ d' | grep 'T{\|T}' | grep "\b$capability[^[:print:]]" | ssam -e '/T{/,/T}/ x/T{|T}/ s/T(.)/\1/' | cut -f4`
  printf "%s -- %s\n" "$capability" "$comment"
done

#!/bin/bash
mapfile terminfo < <( man -w 5 terminfo | xargs zcat | ssam -e 'x/T{/ .,/T}/ x/\n/ d' | grep 'T{\|T}' | ssam -e 'x/T{|T}/ s/T(.)/\1/')
infocmp -1 | grep -ve '^#' | ( read n; cat ) | cut -d= -f1 | tr -cd '[:alpha:][:digit:]\n' | while read capability; do
  comment=`printf "%s" "${terminfo[@]}" | grep "\b$capability[^[:print:]]" | cut -f4`
  printf "%s -- %s\n" "$capability" "$comment"
done

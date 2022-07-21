#!/usr/bin/env bash
mapfile terminfo < <( man -w 5 terminfo | xargs zcat | ssam -e 'x/T{/ .,/T}/ x/\n/ d' | grep 'T{\|T}' | ssam -e 'x/T{|T}/ s/T(.)/\1/')
infocmp -1 | ssam -e 'x/[^     ]*#.*$\n/ v/[^  ]#/ d' | tail -n +2 | cut -f2 | ssam -e 'x/[,=]+.*/ d' | while read record; do
  capability=`printf "%s\n" "$record" | cut -d# -f1`
  comment=`printf "%s" "${terminfo[@]}" | grep "\b$capability\b" | cut -f4 | head -n 1`
  printf "%s -- %s\n" "$record" "$comment"
done

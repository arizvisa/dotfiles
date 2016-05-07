#!/bin/sh

prefix=$( grep "var sWayBackCGI" $1 | cut -d \" -f 2 )

cat $1 | \
xml-tagger img src '(http://.*)' "$prefix\\1" | \
xml-tagger a href '(http://.*)' "$prefix\\1" | \
xml-tagger area href '(http://.*)' "$prefix\\1" | \
xml-tagger object codebase '(http://.*)' "$prefix\\1" | \
xml-tagger object data '(http://.*)' "$prefix\\1" | \
xml-tagger applet codebase '(http://.*)' "$prefix\\1" | \
xml-tagger applet archive '(http://.*)' "$prefix\\1" | \
xml-tagger embed src '(http://.*)' "$prefix\\1" | \
xml-tagger body background '(http://.*)' "$prefix\\1" | \
xml-tagger forms action '(http://.*)' "$prefix\\1"

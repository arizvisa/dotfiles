#!/bin/sh
ls -l | perl -e '$/=undef;$_=<>;print"<pre>\n$_</pre>"' | perl -pe 's/([a-zA-Z_.0-9-]*)$/<a href="$1">$1<\/a>/'

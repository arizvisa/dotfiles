#!/usr/bin/env bash
if [ "${KB}" = "" ]; then
    echo "Usage: KB=KB1234567 $0"
    exit 1
fi

fetch='curl -s -k -L -A ""'
#url="http://search.microsoft.com/en-us/DownloadResults.aspx?q=($KB)"
url='http://www.microsoft.com/en-us/search/DownloadResults.aspx?q=('${KB}')'

tmpprefix="$TMPDIR/msdownload.$$"
${fetch} "$url" | xml-select div class m-search-results | xml-select a class c-hyperlink | tee >(xml-tagger a href >| "$tmpprefix.href") >(xml-tagger a title >| "$tmpprefix.title") | xml-tagger a bi:index >| "$tmpprefix"
cat "$tmpprefix" | paste - <(cat "$tmpprefix.href") <(cat "$tmpprefix.title") | sort -n -k 1 | cut -f2,3
rm -f "$tmpprefix"{,.href,.title}

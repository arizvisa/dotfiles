#!/bin/sh
mingw_get_data=`cygpath $HOMEDRIVE/MinGW/var/lib/mingw-get/data`

list_installed_tarnames()
{
    grep '<installed' $mingw_get_data/* | cut -d: -f2- | xml-tagger installed tarname
}

tarname_to_package()
{
    tarname="$1"
    xmlfile=`grep -l '<software-distribution' $mingw_get_data/* | xargs grep -l "<release tarname=\"$tarname\""`
    cat "$xmlfile" | xml-path "//release[@tarname=\"$tarname\"]/../.."  | xml-tagger package name
}

list_installed_tarnames | while read filename; do
    tarname_to_package "$filename"
done

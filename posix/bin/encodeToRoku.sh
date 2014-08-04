#!/bin/sh
INPUT=$1
OUTPUT=$2

#-f format
#-c codec
#-codec codec
#-vf graph
#-af graph
#
#-scodec

vcodec=libx264
acodec=libvo_aacenc

vbitrate=1000k
vaspect=16:9
vsize=1920x1080

abitrate=128k
asamplingrate=44100

ffmpeg -i "$INPUT" \
    -c:v $vcodec -aspect "$vaspect" -b:v $vbitrate -s $vsize\
    -c:a $acodec -ac 2 -ar $asamplingrate -b:a $abitrate \
    -stats \
    "$OUTPUT"


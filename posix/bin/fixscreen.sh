#!/bin/sh
providers=--listproviders
#Providers: number : 1
#Provider 0: id: 0x4b cap: 0xb, Source Output, Sink Output, Sink Offload crtcs: 4 outputs: 8 associated providers: 0 name:Intel

case `rand.py 0 8 1` in
0)
    xrandr --rate 48
    ;;

1)
    xrandr --rate 60
    ;;

2)
    xrandr --fb 1920x1080
    ;;

3)
    xrandr --fb 1680x1050
    ;;

4)
    xrandr --fb 1400x1050
    ;;

5)
    xrandr --fb 1280x1024
    ;;

6)
    xrandr --fb 1024x768
    ;;

7)
    xrandr --fb 800x600
    ;;

*)
    xrandr --fb 1920x1080 --rate 60
    ;;
esac

#!/bin/sh
cscope=$(which cscope)

$cscope -b -q "$@"



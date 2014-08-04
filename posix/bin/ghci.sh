#!/bin/sh
if test x$(uname -o) == xMsys; then
    dir="/c/Program Files (x86)/Haskell Platform/2013.2.0.0"
    exec "$dir/bin/ghc" --interactive "$@"
else
    exec ghc --interactive "$@"
fi

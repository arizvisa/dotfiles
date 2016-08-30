#!/bin/sh
if "${platform}" == "msys"; then
    dir="${ProgramFiles_x86_}/Haskell Platform/2013.2.0.0"
    exec "$dir/bin/ghc" --interactive "$@"
else
    exec ghc --interactive "$@"
fi

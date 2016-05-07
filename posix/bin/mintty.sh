#!/bin/sh

# C:\MinGW\msys\1.0\bin\mintty.exe -c "c:\users\user\.minttyrc" -h always "C:\MinGW\msys\1.0\bin\bash.exe" --init-file /etc/profile

msys="/c/MingW/msys/1.0"
mintty="$msys/bin/mintty.exe"
bash="$msys/bin/bash.exe"
rcfile="/c/users/user/.minttyrc"

"$mintty" -c "$rcfile" $bash --init-file /etc/profile
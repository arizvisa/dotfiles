#!/usr/bin/env python
from __future__ import with_statement
# also tested with Python 2.6

import os, sys

if len(sys.argv) != 3:
    print(sys.argv[0] + ": Invalid number of arguments.")
    print("Usage: " + sys.argv[0] + " linecount filename")
    print("to remove linecount lines from the end of the file sparsely")
    sys.exit(2)

number = int(sys.argv[1])
file = sys.argv[2]
count = 0

with open(file,'r+b') as f:
    f.seek(0, os.SEEK_END)
    end = f.tell()
    while f.tell() > 0:
        f.seek(-1, os.SEEK_CUR)
        char = f.read(1)
        if char != b'\n' and f.tell() == end:
            print("No change: file does not end with a newline")
            sys.exit(1)
        if char == b'\n':
            count += 1
        if count == number + 1:
            f.truncate()
            print("Removed " + str(number) + " lines from end of file")
            sys.exit(0)
        f.seek(-1, os.SEEK_CUR)

if count < number + 1:
    print("No change: requested removal would leave empty file")
    sys.exit(3)


@echo off
setlocal
SET pdir=
IF EXIST "%ProgramFiles%\Vim" SET pdir=%ProgramFiles%\Vim
IF EXIST "%ProgramW6432%\Vim" SET pdir=%ProgramW6432%\Vim
IF "%pdir%" == "" (
    ECHO "vim.bat: Unable to find Vim in Program Files directory."
    EXIT 1
)
START "" /wait "%pdir%\gvim.exe" %1 %2 %3 %4 %5 %6 %7 %8 %9

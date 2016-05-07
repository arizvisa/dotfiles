@echo off
setlocal
set msys=msys\1.0
set msys_dll=msys-1.0.dll

REM determine path to msys
for /d %%d in ( c: d: e: f: ) do (
    for /d %%p in ( %%d\%msys% %%d\mingw32\%msys% %%d\mingw\%msys% ) do (
        if exist %%p\bin\%msys_dll% set root=%%p
    )
)
if "%root%" == "" goto nomsys

REM determine which executable to run for the terminal
for %%f in ( %root%\bin\rxvt.exe %root%\bin\mintty.exe ) do (
    if exist %%f set terminal=%%f
)
if "%terminal%" == "" goto noterminal

REM determine which shell to run
for %%f in ( %COMSPEC% %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe ) do (
    if exist %%f (
        set shell=%%f
        set type=windows
    )
)

for %%f in ( %root%\bin\csh.exe %root%\bin\sh.exe %root%\bin\bash.exe ) do (
    if exist %%f (
        set shell=%%f
        set type=posix
    )
)
if "%shell%" == "" goto noshell

REM run terminal
cd %USERPROFILE%

if "%type%" == "windows" (
    start /i %terminal% %1 %2 %3 %4 %5 %6 %7 %8 %9 %shell%
) else if "%type%" == "posix" (
    start /i %terminal% %1 %2 %3 %4 %5 %6 %7 %8 %9 %shell% --login -i
) else goto notype

endlocal
exit /b 0

:nomsys
echo Unable to locate Msys path.
exit /b 1

:noterminal
echo Unable to locate a valid terminal emulator.
exit /b 1

:noshell
echo Unable to locate a shell
exit /b 1

:notype
echo Unknown shell type
exit /b 1

@echo off
rem Configuration
set _CONFIG_TIMESTAMP_VARSTART_={{
set _CONFIG_TIMESTAMP_VAREND_=}}
rem Alter the variables below to properly match your localization if you're
rem not from the US and your output of %DATE% is different.
set _CONFIG_TIMESTAMP_WEEKDAY_TOKEN_=1
set _CONFIG_TIMESTAMP_MONTH_TOKEN_=2
set _CONFIG_TIMESTAMP_DAY_TOKEN_=3
set _CONFIG_TIMESTAMP_YEAR_TOKEN_=4

rem Script Start
goto timestamp_premain

:timestamp_strlen
setlocal
set _TIMESTAMP_STRLEN_VARNAME_=%~1
set _TIMESTAMP_STRLEN_BUF_=%~2
set _TIMESTAMP_STRLEN_LEN_=0
goto timestamp_strlen_loop

:timestamp_strlen_loop
if "%_TIMESTAMP_STRLEN_BUF_%x"=="x" goto timestamp_strlen_end
set _TIMESTAMP_STRLEN_CHAR_=%_TIMESTAMP_STRLEN_BUF_:~0,1%
set /A _TIMESTAMP_STRLEN_LEN_ += 1
set _TIMESTAMP_STRLEN_BUF_=%_TIMESTAMP_STRLEN_BUF_:~1%
goto timestamp_strlen_loop

:timestamp_strlen_end
endlocal & call set "%_TIMESTAMP_STRLEN_VARNAME_%=%_TIMESTAMP_STRLEN_LEN_%"
goto :EOF

:timestamp_long_weekday
for %%i in ("Mon=Monday" "Tue=Tuesday" "Wed=Wednesday" "Thu=Thursday" "Fri=Friday" "Sat=Saturday" "Sun=Sunday") do @call set "%~1=%%%~1:%%~i%%"
goto :EOF

:timestamp_datestamp
for /f "tokens=1,2,3,4 delims=/ " %%A in ("%DATE%") do @call :timestamp_datestamp_setter "%~1" "%%~A" "%%~B" "%%~C" "%%~D"
goto :EOF

:timestamp_datestamp_setter
rem TODO: Month and day
call set "%~1_SHORT_WEEKDAY=%%~%_CONFIG_TIMESTAMP_WEEKDAY_TOKEN_%"
call set "%~1_LONG_WEEKDAY=%%~%_CONFIG_TIMESTAMP_WEEKDAY_TOKEN_%"
call :timestamp_long_weekday "%~1_LONG_WEEKDAY"
call set "%~1_MONTH=%%~%_CONFIG_TIMESTAMP_MONTH_TOKEN_%"
call set "%~1_MONTH_SHORT=%%~%_CONFIG_TIMESTAMP_MONTH_TOKEN_%"
call set "%~1_MONTH_LONG=%%~%_CONFIG_TIMESTAMP_MONTH_TOKEN_%"
call set "%~1_DAY=%%~%_CONFIG_TIMESTAMP_DAY_TOKEN_%"
call set "%~1_DAY_SHORT=%%~%_CONFIG_TIMESTAMP_DAY_TOKEN_%"
call set "%~1_YEAR=%%~%_CONFIG_TIMESTAMP_YEAR_TOKEN_%"
call set "%~1_YEAR_SHORT=%%%~1_YEAR:~2,2%%"
goto :EOF

:timestamp_timestamp
for /f "tokens=1,2,3,4 delims=:." %%A in ("%TIME%") do @call :timestamp_timestamp_setter "%~1" "%%~A" "%%~B" "%%~C" "%%~D"
goto :EOF

:timestamp_timestamp_setter
call set %~1_24HOUR=%%~2
call set %~1_12HOUR=%%~2
call set %~1_MIN=%%~3
call set %~1_SEC=%%~4
call set %~1_MSEC=%%~5

if %~2 EQU 0 (
	call set %~1_12HOUR=12
	call set %~1_AMPM=AM
) else if %~2 EQU 12 (
	call set %~1_AMPM=PM
) else if %~2 GTR 12 (
	call set /A %~1_12HOUR=%~2 - 12
	call set %~1_AMPM=PM
) else (
	call set %~1_AMPM=AM
)
goto :EOF

rem TODO: Add a check for varname at %~1
:timestamp_format
:timestamp
call :timestamp_timestamp %~1
call :timestamp_datestamp %~1
setlocal
set _TIMESTAMP_FORMAT_VARNAME_=%~1
set _TIMESTAMP_FORMAT_FMT_=%~2
if "%_TIMESTAMP_FORMAT_FMT_%x"=="x" set _TIMESTAMP_FORMAT_FMT_=%_CONFIG_TIMESTAMP_VARSTART_%dd%_CONFIG_TIMESTAMP_VAREND_% %_CONFIG_TIMESTAMP_VARSTART_%MM%_CONFIG_TIMESTAMP_VAREND_%/%_CONFIG_TIMESTAMP_VARSTART_%DD%_CONFIG_TIMESTAMP_VAREND_%/%_CONFIG_TIMESTAMP_VARSTART_%YYYY%_CONFIG_TIMESTAMP_VAREND_% %_CONFIG_TIMESTAMP_VARSTART_%hh%_CONFIG_TIMESTAMP_VAREND_%:%_CONFIG_TIMESTAMP_VARSTART_%mm%_CONFIG_TIMESTAMP_VAREND_%:%_CONFIG_TIMESTAMP_VARSTART_%SS%_CONFIG_TIMESTAMP_VAREND_%:%_CONFIG_TIMESTAMP_VARSTART_%ss%_CONFIG_TIMESTAMP_VAREND_% %_CONFIG_TIMESTAMP_VARSTART_%AMPM%_CONFIG_TIMESTAMP_VAREND_%
set _TIMESTAMP_FORMAT_BUF_=%_TIMESTAMP_FORMAT_FMT_%
set _TIMESTAMP_FORMAT_RESFMT_=
call :timestamp_strlen _CONFIG_TIMESTAMP_STARTLEN_ "%_CONFIG_TIMESTAMP_VARSTART_%"
call :timestamp_strlen _CONFIG_TIMESTAMP_ENDLEN_ "%_CONFIG_TIMESTAMP_VAREND_%"
goto timestamp_format_loop

:timestamp_format_loop
if "%_TIMESTAMP_FORMAT_BUF_%x"=="x" goto timestamp_format_end
call set _TIMESTAMP_FORMAT_CHECK_=%%_TIMESTAMP_FORMAT_BUF_:~0,%_CONFIG_TIMESTAMP_STARTLEN_%%%
if "%_TIMESTAMP_FORMAT_CHECK_%"=="%_CONFIG_TIMESTAMP_VARSTART_%" goto timestamp_format_varstart
set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%_TIMESTAMP_FORMAT_BUF_:~0,1%
set _TIMESTAMP_FORMAT_BUF_=%_TIMESTAMP_FORMAT_BUF_:~1%
goto timestamp_format_loop

:timestamp_format_varstart
call set _TIMESTAMP_FORMAT_VAR_BUF_=%%_TIMESTAMP_FORMAT_BUF_:~%_CONFIG_TIMESTAMP_STARTLEN_%%%
call set _TIMESTAMP_FORMAT_VAR_RESULT_=
goto timestamp_format_varloop

:timestamp_format_varloop
if "%_TIMESTAMP_FORMAT_VAR_BUF_%x"=="x" (
	echo Error: Unclosed format variable: %_TIMESTAMP_FORMAT_VAR_RESULT_%
	exit /B %ERRORLEVEL%
)
call set _TIMESTAMP_FORMAT_CHECK_=%%_TIMESTAMP_FORMAT_VAR_BUF_:~0,%_CONFIG_TIMESTAMP_ENDLEN_%%%
if "%_TIMESTAMP_FORMAT_CHECK_%"=="%_CONFIG_TIMESTAMP_VAREND_%" goto timestamp_format_varend
set _TIMESTAMP_FORMAT_VAR_RESULT_=%_TIMESTAMP_FORMAT_VAR_RESULT_%%_TIMESTAMP_FORMAT_VAR_BUF_:~0,1%
set _TIMESTAMP_FORMAT_VAR_BUF_=%_TIMESTAMP_FORMAT_VAR_BUF_:~1%
goto timestamp_format_varloop

:timestamp_format_varend
if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="dd" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_SHORT_WEEKDAY%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="dddd" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_LONG_WEEKDAY%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="D" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_DAY_SHORT%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="DD" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_DAY%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="M" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_MONTH_SHORT%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="MM" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_MONTH%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="MMMM" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_MONTH_LONG%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="YY" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_YEAR_SHORT%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="YYYY" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_YEAR%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="hh" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_12HOUR%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="HH" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_24HOUR%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="mm" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_MIN%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="SS" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_SEC%%
) else if "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="ss" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_MSEC%%
) else if /i "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="AM" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_AMPM%%
) else if /i "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="PM" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_AMPM%%
) else if /i "%_TIMESTAMP_FORMAT_VAR_RESULT_%"=="AMPM" (
	set _TIMESTAMP_FORMAT_RESFMT_=%_TIMESTAMP_FORMAT_RESFMT_%%%%_TIMESTAMP_FORMAT_VARNAME_%_AMPM%%
) else (
	echo Unrecognized format string: %_TIMESTAMP_FORMAT_RESFMT_%
)
set _TIMESTAMP_FORMAT_VAR_RESULT_=
call set _TIMESTAMP_FORMAT_BUF_=%%_TIMESTAMP_FORMAT_VAR_BUF_:~%_CONFIG_TIMESTAMP_ENDLEN_%%%
goto timestamp_format_loop

:timestamp_format_end
endlocal & call set "%_TIMESTAMP_FORMAT_VARNAME_%=%_TIMESTAMP_FORMAT_RESFMT_%"
goto :EOF

:timestamp_premain
call set /A _CONFIG_TIMESTAMP_WEEKDAY_TOKEN_=%_CONFIG_TIMESTAMP_WEEKDAY_TOKEN_% + 1
call set /A _CONFIG_TIMESTAMP_MONTH_TOKEN_=%_CONFIG_TIMESTAMP_MONTH_TOKEN_% + 1
call set /A _CONFIG_TIMESTAMP_DAY_TOKEN_=%_CONFIG_TIMESTAMP_DAY_TOKEN_% + 1
call set /A _CONFIG_TIMESTAMP_YEAR_TOKEN_=%_CONFIG_TIMESTAMP_YEAR_TOKEN_% + 1
goto timestamp_main

:timestamp_test
setlocal
call :timestamp TEST_TS "%~1"
echo "%~1" =^> "%TEST_TS%"
endlocal
goto :EOF

:timestamp_main
call :timestamp_test "{{hh}}:{{mm}} {{AMPM}} {{dd}}, {{M}}/{{D}}/{{YY}}"
call :timestamp_test "[{{MM}}-{{DD}}-{{YYYY}} -- {{HH}}:{{mm}}:{{SS}}:{{ss}}]"

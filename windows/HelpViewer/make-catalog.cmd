@echo off
set language=en-US
set base=%ProgramData%\Microsoft\HelpLibrary2\Catalogs

if [%1] == [] (
    echo Please provide a catalog name as the first argument.
    set errorlevel=1
    goto leave
)

mkdir "%base%\%1"
pushd "%base%\%1"

mkdir "ContentStore\%language%"
mkdir "Incoming\Cab"
mkdir "IndexStore\%language%"

echo ^<?xml version="1.0" encoding="utf-8"?^>^<catalogType^>UserManaged^</catalogType^> > CatalogType.xml
popd

:leave

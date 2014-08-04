function lsd {
    ls | where { $_.PsIsContainer }
}

function addpath {
    param ($path);
    if (-not $path) {
        $path = $(pwd).path;
        echo "path not specified, adding current directory: $path";
    }
    $env:PATH = $path + ";" + $env:PATH;
}

function addpythonpath {
    param ($path);
    if (-not $path) {
        $path = $(pwd).path;
        echo "path not specified, adding current directory: $path";
    }
    $env:PYTHONPATH = $path + ";" + $env:PYTHONPATH;
}

function unixfind {
    ls -recurse | %{ $_.FullName }
}

set-alias ss select-string
# set-alias grep select-string

function searchin {
    param ($string);
    foreach ($file in $input) {
        select-string $string $file
    }
}

$vsver = "9.0"
$sdkver = "v7.1"
$x86 = " (x86)"

# visual studio shit
$env:PATH += ";" + "C:\Program Files$x86\Microsoft Visual Studio $vsver\vc\bin"
#$env:PATH += ";" + "C:\Program Files$x86\Microsoft SDKs\Windows\$sdkver\bin"

$env:INCLUDE += ";" + "C:\Program Files$x86\Microsoft Visual Studio $vsver\vc\include"
$env:LIB += ";" + "C:\Program Files$x86\Microsoft Visual Studio $vsver\vc\lib"

$env:INCLUDE += ";" + "C:\Program Files\Microsoft SDKs\Windows\$sdkver\include"
$env:LIB += ";" + "C:\Program Files\Microsoft SDKs\Windows\$sdkver\lib"

# my shit
addpath "C:/Program Files (x86)/Vim/vim72"

# tools
addpath "C:/Program Files (x86)/Git/cmd"
addpath "C:/Program Files (x86)/Mercurial"
addpath "C:/Program Files/SlikSvn/bin/"

#addpath $env:USERPROFILE+"/tools"
addpath "f:/tools"

# languages
addpath "C:/Python26"
addpath "C:/Program Files (x86)/Objective Caml/bin"

# d
#addpath "C:/D/dmd/windows/bin"
#addpath "C:/D/dmd2/windows/bin"
#addpath "C:/D/dm/bin"

# plan9
$env:PLAN9 = $HOME

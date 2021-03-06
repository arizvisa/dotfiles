$env:POWERSHELL_TELEMETRY_OPTOUT = $true

$Global:InformationPreference = "Continue"
$Global:WarningPreference = "Continue"
$Global:DebugPreference = "SilentlyContinue"
$Global:VerbosePreference = "SilentlyContinue"

Set-PSReadLineOption -EditMode Vi

## Posix aliases
Set-Alias -Name ls -Value Get-ChildItem
Set-Alias -Name alias -Value Get-Alias
Set-Alias -Name jobs -Value Get-Job
Set-Alias -Name job -Value Receive-Job

function lsd {
    ls | where { $_.PsIsContainer }
}

function find {
    ls -recurse | %{ $_.FullName }
}

#set-alias ss select-string
set-alias grep select-string

## Environment (variables)
$Global:OS = (Test-Path Env:OS)? $Env:OS : $Env:os
if ($Global:OS -eq "posix") {
    $Global:USERPROFILE = $Env:USERPROFILE ?? $Env:HOME
} else {
    $Global:HOME = $Env:HOME ?? $Env:USERPROFILE
}
$Global:PATHSEP = ($Global:OS -eq "posix")? ":" : ";"
$Global:SEP = ($Global:OS -eq "posix")? "/" : "\"

## Utilities
function searchin {
    param ($string);
    foreach ($file in $input) {
        select-string $string $file
    }
}

function addvariablepath {
    param ($var, $path);

    if (-not $path) {
        $path = $(pwd).path;
        write-warning "path not specified, adding current directory: $path"
    }

    if (test-path "env:$var") {
        $contents = get-content -path env:$var
        set-content -path env:$var -value (($contents,$path) -join $Global:PATHSEP)
    } else {
        new-item -path env:$var -value "$path"
    }
}

function addpath {
    param ($path);
    addvariablepath "PATH" "$path"
}

function addpythonpath {
    param ($path);
    addvariablepath "PYTHONPATH" "$path"
}

function StringSplitAny ([String]$string, [String]$ifs = " `u{09}`u{0A}`u{0D}") {
    $result = @()
    $state = $null
    $fieldseparator = $ifs -split ""
    $string -split "" | Where-Object { $_.Length } | ForEach-Object {
        if ($fieldseparator -contains $_) {
            $result += $state
            $state = $null
        } else {
            $state = ($state ?? "") + $_
        }
    }
    if ($state -ne $null) {
        $result += $state
    }
    return $result
}

## Site
if ($Global:OS -ne "posix") {
    $vsver = "9.0"
    $sdkver = "v7.1"
    $ProgramFilesX86 = $env:ProgramFiles

    addpath ("{0}\Microsoft Visual Studio {1}\vc\bin" -f $env:ProgramFilesX86,$vsver)
    #addpath ("{0}\Microsoft SDKs\Windows\{1}\bin" -f $env:ProgramFilesX86,$sdkver)

    addvariablepath "INCLUDE" ("{0}\Microsoft Visual Studio {1}\vc\include" -f $env:ProgramFilesX86,$vsver)
    addvariablepath "LIB" ("{0}\Microsoft Visual Studio {1}\vc\lib" -f $env:ProgramFilesX86,$vsver)

    addvariablepath "INCLUDE" ("{0}\Microsoft SDKs\Windows\{1}\include" -f $env:ProgramFiles,$sdkver)
    addvariablepath "LIB" ("{0}\Microsoft SDKs\Windows\{1}\lib" -f $env:ProgramFiles,$sdkver)
}

## Remoting
$variable = (Test-Path -Path Env:REMOTE)? [String](Get-Content -Path Env:REMOTE) : ""
$session_hosts = ($variable.Length -gt 0)? @(StringSplitAny $variable) : @()
Remove-Variable -Name variable

if ($session_hosts.Length -gt 0) {
    $session_options = New-PSSessionOption -SkipCACheck -SkipCNCheck -Verbose
    $session_creds = Get-Credential -UserName $env:USER -Message ("Requesting credentials for username `"{0}`"." -f $env:USER) -Title ("Attempting connection to {0} host{1}." -f $session_hosts.Length,($session_hosts.Length -eq 1? "" : "s"))

    $session = $session_hosts | ForEach-Object {
        Write-Information ("Creating new PSSession for host `"{1}@{0}`"" -f $_,$session_creds.UserName)
        New-PSSession -ComputerName $_ -Authentication Negotiate -Credential $session_creds -SessionOption $session_options
    }
}

## Local
addpath "{0}/Git/cmd" -f $env:ProgramFiles
addpath "{0}/tools" -f $env:USERPROFILE

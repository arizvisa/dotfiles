$env:POWERSHELL_TELEMETRY_OPTOUT = $true
$env:DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER = $false

$Global:InformationPreference = "Continue"
$Global:WarningPreference = "Continue"
$Global:DebugPreference = "SilentlyContinue"
$Global:VerbosePreference = "SilentlyContinue"

# it appears that when the PSReadLineOption EditMode is set to Vi,
# the escape chord is not consistently detected on both powershell
# core ($PSEdition -eq "Core") or powershell desktop ($PSEdition -eq "Desktop").
# so we instead use the PSReadLineOption EditMode set to Emacs. this is
# okay, since I grew up with emacs as my first editor anyways...
#Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor

# colors so that things are readable on a partially transparent background
Set-PSReadLineOption -Colors @{
    "Command"               = "#C0C0C0"
    "ContinuationPrompt"    = "#C0C0C0"
    "Default"               = "#C0C0C0"
    "Member"                = "#C0C0C0"
    "Number"                = "#E0E0E0"
    "Emphasis"              = "#FFFFFF"
    "Operator"              = "#20FF20"
    "Parameter"             = "#E0E0E0"
    "Error"                 = "#FF2020"
    "Comment"               = "#C0C0FF"
    "String"                = "#E0E0E0"
    "Keyword"               = "#40FF40"
}

## Posix aliases
Set-Alias -Option AllScope -Name ls -Value Get-ChildItem
Set-Alias -Option AllScope -Name alias -Value Get-Alias
Set-Alias -Option AllScope -Name jobs -Value Get-Job
Set-Alias -Option AllScope -Name job -Value Receive-Job

function lsd {
    Get-ChildItem @($args) | Where-Object { $_.PsIsContainer }
}

function find {
    Get-ChildItem -recurse @($args) | %{ $_.FullName }
}

#Set-Alias ss select-string
Set-Alias grep select-string

## Environment (variables)
$Global:OS = @($Env:OS, $Env:os)[!(Test-Path Env:OS)]
if ($Global:OS -eq "posix") {
    $Global:USERPROFILE = @($Env:USERPROFILE, $Env:HOME)[!$Env:USERPROFILE]

# If the global variable is already set on Windows, then forcefully
# remove it and assign it using the USERPROFILE environment variable.
} else {
    if ($Global:HOME) {
        Remove-Variable -Name HOME -Force
    }
    $Global:HOME = @($Env:HOME, $Env:USERPROFILE)[!$Env:HOME]
}
$Global:PATHSEP = @(":", ";")[!($Global:OS -eq "posix")]
$Global:SEP = @("/", "\")[!($Global:OS -eq "posix")]

## Utilities
function searchin {
    param ($string);
    foreach ($file in $input) {
        Select-String $string $file
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
        new-item -path env:$var -value "$path" | Out-Null
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
            $state = @($state, "")[!$state] + $_
        }
    }
    if ($state -ne $null) {
        $result += $state
    }
    return $result
}

# ripped mostly from https://stackoverflow.com/questions/1078920/equivalent-of-more-or-less-command-in-powershell
function Pager {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true)]$$
    )

    # construct a steppable pipeline for Out-Host using our current invocation
    begin {
        $command = $ExecutionContext.InvokeCommand.GetCommand('Out-Host', [System.Management.Automation.CommandTypes]::Cmdlet)
        $pager = { & $command @($PSBoundParameters) -Paging }
        $pipeline = $pager.GetSteppablePipeline($myInvocation.CommandOrigin)
        $pipeline.Begin($PSCmdlet)
    }

    # feed each block of input to our pipeline
    process {
        try {
            $pipeline.Process($_)
        } catch {
            break
        }
    }

    # close the pipeline when we're done
    end {
        $pipeline.End()
    }
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
if (Test-Path -Path Env:REMOTE) {
    $variable = [String](Get-Content -Path Env:REMOTE)
} else {
    $variable = ""
}
$session_hosts = @( @(StringSplitAny $variable), @() )[!($variable.Length -gt 0)]
Remove-Variable -Name variable

if ($session_hosts.Length -gt 0) {
    $session_options = New-PSSessionOption -SkipCACheck -SkipCNCheck -Verbose
    $session_creds = Get-Credential -UserName $env:USER -Message ("Requesting credentials for username `"{0}`"." -f $env:USER) -Title ("Attempting connection to {0} host{1}." -f $session_hosts.Length,@("", "s")[!($session_hosts.Length -eq 1)])

    $session = $session_hosts | ForEach-Object {
        Write-Information ("Creating new PSSession for host `"{1}@{0}`"" -f $_,$session_creds.UserName)
        New-PSSession -ComputerName $_ -Authentication Negotiate -Credential $session_creds -SessionOption $session_options
    }
}

## Local
addpath "{0}/Git/cmd" -f $env:ProgramFiles
addpath "{0}/tools" -f $env:USERPROFILE

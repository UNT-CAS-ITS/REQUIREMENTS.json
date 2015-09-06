function Get-RequirementCommand ($Command, $Path, $Import) {
    if ($Command.Contains(' ') -and -not ($Command.StartsWith('"') -or $Command.StartsWith(''''))) {
        # Get-Command doesn't error if $Command contains a space.
        Throw('[REQUIREMENTS.json][Get-RequirementCommand] Command should not contain a space; can bypass this by wrapping Command in quotes')
    }

    switch -wildcard ($Import) {
        '.' {
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Import` is "."'

            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] Does `Command` exist?'
            if (Get-Command $Command -ErrorAction Ignore) {
                Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists.'
                return @('Command', $Command)
            }
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` doesn''t exist.'
        }
        'Import-Module' {
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Import` is "Import-Module"'

            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] Does `Command` exist?'
            if (Get-Command $Command -ErrorAction Ignore) {
                Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists.'
                return @('Command', $Command)
            }
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` doesn''t exist.'
        }
        $null {
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] Likely a binary file. Check that `Path` + `Command` exists.'
            $PathCommand = Join-RequirementPathCommand -Path $Path -Command $Command

            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] Does `Path` + `Command` exist?'
            if (Test-Path $PathCommand) {
                Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Path` + `Command` exists.'
                return @('PathCommand', $PathCommand)
            }
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Path` + `Command` doesn''t exist.'
        }
        default {
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Import` unhandled; check Verbose output for more information.'
            Write-Verbose @"
[REQUIREMENTS.json][Get-RequirementCommand] ``Import`` unhandled.
Assuming your ``Command``, ``Import``, and ``Path`` will just work.
If that doesn't work, check for and/or submit an issue: https://github.com/Vertigion/REQUIREMENTS.json/issues
Include this verbose message and your REQUIREMENTS.json file contents.
Import: ${Import}
Import.GetType(): $($Import.GetType())
Import.GetType().FullName: $($Import.GetType().FullName)
Current global:REQUIREMENTS:
$($global:REQUIREMENTS | Format-List | Out-String)
"@
            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists as a file?'
            if (Test-Path $Command) {
                Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists as a file.'
                return @('Command', $Command)
            }

            Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists as a command?'
            if (Get-Command $Command -ErrorAction Ignore) {
                Write-Debug '[REQUIREMENTS.json][Get-RequirementCommand] `Command` exists as a command.'
                return @('Command', $Command)
            }
        }
    }

    return $false
}

function Invoke-RequirementDownload ($URL, $Path) {
    if ($URL.EndsWith('.zip')) {
        Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] URL is ZipFile'
        $zip_guid = [GUID]::NewGUID()

        Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Downloading to: ${env:Temp}\requirement_${zip_guid}.zip"
        Invoke-WebRequest $URL -OutFile "${env:Temp}\requirement_${zip_guid}.zip" -UseBasicParsing

        if (Test-Path (Split-Path $Path -Parent)) {
            Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] Deleting current `Path` Parent'
            Remove-Item (Split-Path $Path -Parent) -Force -Recurse
        }

        if ($Path.EndsWith('\')) {
            if (Test-Path $Path) {
                Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] Deleting current `Path`'
                Remove-Item $Path -Force -Recurse
            }

            $Parent = $Path
        } else {
            if (Test-Path (Split-Path $Path -Parent)) {
                Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] Deleting current `Path` Parent'
                Remove-Item (Split-Path $Path -Parent) -Force -Recurse
            }

            $Parent = Split-Path $Path -Parent
        }
        
        if (-not (Test-Path $Parent)) {
            New-Item -ItemType Directory -Force -Path $Parent | %{ Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Created Directory: $_" }
        }

        Add-Type -Assembly 'System.IO.Compression.FileSystem'
        Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Unzipping the ZipFile to: ${Parent}"
        [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path "${env:Temp}\requirement_${zip_guid}.zip"), (Resolve-Path $Parent))

        Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Deleting the ZipFile"
        Remove-Item "${env:Temp}\requirement_${zip_guid}.zip"
    } else {
        Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] URL is not a ZipFile'
        $Parent = Split-Path $Path -Parent
        if (-not (Test-Path $Parent)) {
            New-Item -ItemType Directory -Force -Path $Parent | %{ Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Created Directory: $_" }
        }

        if ($Path.EndsWith('\')) {
            $www = Invoke-WebRequest $URL -UseBasicParsing
            if ($www.Headers.'Content-Disposition') {
                $OutFile = $www.Headers.'Content-Disposition'.Split(';')[1].Split('=')[1].Trim()
                Write-Debug "[REQUIREMENTS.json][Invoke-RequirementDownload] Downloading to ``Path``: ${OutFile}"
                Invoke-WebRequest $URL -OutFile "${Path}${OutFile}" -UseBasicParsing
            } else {
                Write-Debug "Web Headers do not contain Content-Disposition; try setting ``Path`` to a full path. More info: https://github.com/Vertigion/REQUIREMENTS.json/wiki/Keys#other-files"
                Throw [System.Management.Automation.ItemNotFoundException] "Web Headers do not contain Content-Disposition; try setting ``Path`` to a full path."
            }
        } else {
            Write-Debug '[REQUIREMENTS.json][Invoke-RequirementDownload] Downloading to `Path`'
            Invoke-WebRequest $URL -OutFile $Path -UseBasicParsing
        }
    }
}

function Invoke-RequirementImport ($Import, $Path) {
    switch -wildcard ($Import) {
        '.' {
            if (Test-Path $Path) {
                Write-Debug "[REQUIREMENTS.json][Invoke-RequirementImport] Importing: . ${Path}"
                # Importing within a function keeps imports within the scope of the funtion
                return ". ""${Path}"""
            } else {
                Write-Debug "[REQUIREMENTS.json][Invoke-RequirementImport] Unable to Import (``Path`` doesn't exist): . ${Path}"
            }
        }
        'Import-Module' {
            Write-Debug '[REQUIREMENTS.json][Invoke-RequirementImport] Import-Module expects path to be the FullPath to the module (.psm1/.psd1) file.'

            Write-Debug '[REQUIREMENTS.json][Invoke-RequirementImport] Does `Path` exist?'
            if (Test-Path $Path) {
                Write-Debug '[REQUIREMENTS.json][Invoke-RequirementImport] `Path` exists.'
                try {
                    # Importing within a modules within a function is fine.
                    Import-Module $Path -ErrorAction Stop

                    return $true
                } catch {
                    Write-Debug "[REQUIREMENTS.json][Invoke-RequirementImport] Import-Module failed: $_"
                }
            } else {
                Write-Debug '[REQUIREMENTS.json][Invoke-RequirementImport] `Path` doesn''t exist.'
            }
        }
        $null {
            Write-Debug '[REQUIREMENTS.json][Invoke-RequirementImport] Likely a binary file. Do nothing.'
        }
        default {
            Write-Debug "[REQUIREMENTS.json][Invoke-RequirementImport] ``Import`` unhandled; check Verbose output for more information."
            Write-Verbose @"
[REQUIREMENTS.json][Invoke-RequirementImport] ``Import`` unhandled.
Assuming your ``Import`` will just work within ``Invoke-Expression``.
If that doesn't work, check for and/or submit an issue: https://github.com/Vertigion/REQUIREMENTS.json/issues
Include this verbose message and your REQUIREMENTS.json file contents.
Import: ${Import}
Import.GetType(): $($Import.GetType())
Import.GetType().FullName: $($Import.GetType().FullName)
Current global:REQUIREMENTS:
$($global:REQUIREMENTS | Format-List | Out-String)
"@
            # Not sure what this import command is, so let's just return it to ensure the scope is correct
            return $Import
        }
    }

    return $false
}

function Join-RequirementPathCommand ($Path, $Command) {
    if ($Command.StartsWith('"')) {
        $PathCommand = Join-Path $Path $Command.Trim('"')
    } elseif ($Command.StartsWith('''')) {
        $PathCommand = Join-Path $Path $Command.Trim('''')
    } else {
        $PathCommand = Join-Path $Path $Command
    }
    Write-Debug "[REQUIREMENTS.json][Get-RequirementCommand] ``Path`` + ``Command``: ${PathCommand}"
    return $PathCommand
}

############################################################################
# Start of Script Logic
############################################################################

Write-Debug "[REQUIREMENTS.json] MyInvocation.MyCommand.Path: $($MyInvocation.MyCommand.Path)"
Write-Debug "[REQUIREMENTS.json] Get-Location: $(Get-Location)"

$MyInvocationPathParent = if ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Parent } else {  Get-Location }
$MyInvocationPathLeaf = if ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Leaf } else {  $null }

$REQUIREMENTS_json_imported = $false
$REQUIREMENTS_json_locations = @(
    "${MyInvocationPathParent}\${MyInvocationPathLeaf}_REQUIREMENTS.json",
    "$(Get-Location)\${MyInvocationPathLeaf}_REQUIREMENTS.json",
    "${MyInvocationPathParent}\REQUIREMENTS.json",
    "$(Get-Location)\REQUIREMENTS.json"
)

foreach ($location in $REQUIREMENTS_json_locations) {
    try {
        $REQUIREMENTS_json = Get-Content $location -ErrorAction Stop
        $REQUIREMENTS_json_imported = $true
    } catch [System.Management.Automation.ItemNotFoundException] {
        Write-Debug "[REQUIREMENTS.json] REQUIREMENTS.json not here: ${location}"
    }
}

if (-not $REQUIREMENTS_json_imported)
Throw [System.Management.Automation.ItemNotFoundException] @"
[REQUIREMENTS.json] Cannot find 'REQUIREMENTS.json' because it does not exist in the following locations:
`t$($REQUIREMENTS_json_locations -join "`n`t")
"@

try {
    Set-Variable 'REQUIREMENTS' -Scope 'global' -Value (ConvertFrom-Json ($REQUIREMENTS_json | Out-String) -ErrorAction Stop) -ErrorAction Stop
} catch [System.Management.Automation.SessionStateUnauthorizedAccessException] {
    Write-Warning @"
The global:REQUIREMENTS variable likely already exists and needs to be deleted.
The global:REQUIREMENTS variable is a required part of REQUIREMENTS.json; it supplies you with the evaluated/used variable results.
More information:  https://github.com/Vertigion/REQUIREMENTS.json/wiki/global:REQUIREMENTS
You can delete with the variable with this command: ``Remove-Variable 'REQUIREMENTS' -Scope 'global' -Force``
"@
    Throw $error[0]
} catch [System.ArgumentException] {
    Write-Warning @"
Your REQUIREMENTS.json file likely contains invalid JSON (review the error following this message to be sure).
There are many free services online for JSON validation; my favorite: http://jsonlint.com
"@
    Throw $error[0]
}

Write-Debug "[REQUIREMENTS.json] global:REQUIREMENTS: $($global:REQUIREMENTS | Out-String)"

# Reformat `$global:REQUIREMENTS` to something useful 
$i = 0
foreach ($requirement in $global:REQUIREMENTS) {
    Write-Debug "[REQUIREMENTS.json] $($requirement | Out-String)"

    foreach ($j in 1..2) {
        # Running through this twice will ensure our `_f` variables are evaluated; regardless of the order.
        # Example: "Command_f": "$Path"

        $Command_f = if ($requirement.Command_f) { Invoke-Expression $requirement.Command_f } else { '' }
        $Command = $requirement.Command -f $Command_f
        
        $URL_f = if ($requirement.URL_f) { Invoke-Expression $requirement.URL_f } else { '' }
        $URL = $requirement.URL -f $URL_f
        
        $Path_f = if ($requirement.Path_f) { Invoke-Expression $requirement.Path_f } else { '' }
        $Path = $requirement.Path -f $Path_f
        
        if ($requirement.Import) {
            $Import_f = if ($requirement.Import_f) { Invoke-Expression $requirement.Import_f } else { '' }
            $Import = $requirement.Import -f $Import_f
        }
    }

    # Set final expected variables to global.
    $global:REQUIREMENTS[$i].Command = $Command
    $global:REQUIREMENTS[$i].URL = $URL
    $global:REQUIREMENTS[$i].Path = $Path
    if ($global:REQUIREMENTS[$i].Import) {
        $global:REQUIREMENTS[$i].Import = $Import
    }
    
    # Clear out `_f` variables from the global variable. We only want the final variables in global.
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Command_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('URL_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Path_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Import_f')

    Write-Debug "[REQUIREMENTS.json] $($requirement | Out-String)"

    Write-Debug '[REQUIREMENTS.json] Attempting to import the requirement ...'
    $Import = Invoke-RequirementImport -Import $requirement.Import -Path $requirement.Path
    if ($Import -is 'bool') {
        if ($Import) {
            Write-Debug '[REQUIREMENTS.json] Import Successful'
        } else {
            Write-Debug '[REQUIREMENTS.json] Import Unsuccessful'
        }
    } else {
        try {
            Invoke-Expression $Import -ErrorAction Stop
        } catch {
            Write-Debug "[REQUIREMENTS.json] Import Unsuccessful: $_"
        }
    }

    Write-Debug '[REQUIREMENTS.json] Test if `Command` exists ...'
    $Command = Get-RequirementCommand -Command $requirement.Command -Path $requirement.Path -Import $requirement.Import

    if ($Command) {
        Write-Debug '[REQUIREMENTS.json] `Command` exists; setting global:REQUIREMENTS.'
        $global:REQUIREMENTS[$i][$Command[0]] = $Command[1]
    } else {
        Write-Debug '[REQUIREMENTS.json] `Command` does NOT exist.'

        Write-Debug '[REQUIREMENTS.json] Downloading the requirement ...'
        Invoke-RequirementDownload -URL $requirement.URL -Path $requirement.Path

        Write-Debug '[REQUIREMENTS.json] Importing the requirement ...'
        $Import = Invoke-RequirementImport -Import $requirement.Import -Path $requirement.Path
        if ($Import -is 'bool') {
            if ($Import) {
                Write-Debug '[REQUIREMENTS.json] Import Successful'
            } else {
                Write-Debug '[REQUIREMENTS.json] Import Unsuccessful'
            }
        } else {
            try {
                Invoke-Expression $Import -ErrorAction Stop
            } catch {
                Write-Debug "[REQUIREMENTS.json] Import Unsuccessful: $_"
            }
        }

        Write-Debug '[REQUIREMENTS.json] Test if `Command` exists ...'
        $Command = Get-RequirementCommand -Command $requirement.Command -Path $requirement.Path -Import $requirement.Import
        
        if ($Command) {
            Write-Debug '[REQUIREMENTS.json] `Command` exists; setting global:REQUIREMENTS.'
            $global:REQUIREMENTS[$i][$Command[0]] = $Command[1]
        } else {
            Write-Warning @"
Command ($($requirement.Command)) still doesn't exist after download and re-import.
Try testing/debugging your REQUIREMENT.json: https://github.com/Vertigion/REQUIREMENTS.json/wiki/Testing
If you're still getting errors, check issues: https://github.com/Vertigion/REQUIREMENTS.json/issues
Submit an issue if you can't find your issue; I'm glad to help.
"@
            Throw [System.Management.Automation.CommandNotFoundException] "Command ($($requirement.Command)) still doesn't exist after download and re-import."
        }
    }

    $i++
}

# Make `$global:REQUIREMENTS` readonly.
# Chose RO instead of Constant so developers can clear it out if they want to:
# Remove-Variable 'REQUIREMENTS' -Scope 'global' -Force
Set-Variable 'REQUIREMENTS' -Scope 'global' -Option 'ReadOnly' -Value $global:REQUIREMENTS

# Delete our functions
Remove-Item function:Get-RequirementCommand -Force
Remove-Item function:Invoke-RequirementDownload -Force
Remove-Item function:Invoke-RequirementImport -Force
Remove-Item function:Join-RequirementPathCommand -Force
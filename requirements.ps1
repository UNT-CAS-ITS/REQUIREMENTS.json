$ErrorActionPreference = 'Stop'

$my_path = if ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Parent } else { Get-Location }
Write-Debug "[REQUIREMENTS.json] My Path: ${my_path}"

try {
    Set-Variable 'REQUIREMENTS' -Scope 'global' -Value (ConvertFrom-Json (Get-Content "${my_path}\REQUIREMENTS.json" | Out-String))
} catch {
    $msg = @"
The global:REQUIREMENTS variable probably already exists and needs to be deleted.
It is required for this script to supply your with the evaluated/used variable results.
Your delete with this command: ``Remove-Variable 'REQUIREMENTS' -Scope 'global' -Force``
Error: $_
"@
    Throw($msg)
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
        
        $Import_f = if ($requirement.Import_f) { Invoke-Expression $requirement.Import_f } else { '' }
        $Import = $requirement.Import -f $Import_f
    }

    # Set final expected variables to global.
    $global:REQUIREMENTS[$i].Command = $Command
    $global:REQUIREMENTS[$i].URL = $URL
    $global:REQUIREMENTS[$i].Path = $Path
    $global:REQUIREMENTS[$i].Import = $Import
    
    # Clear out `_f` variables from the global variable. We only want the final variables in global.
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Command_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('URL_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Path_f')
    $global:REQUIREMENTS[$i].PSObject.Properties.Remove('Import_f')

    $i++
}

# Make `$global:REQUIREMENTS` readonly.
# Chose RO instead of Constant so you developers can clear it out if they want to:
# Remove-Variable 'REQUIREMENTS' -Scope 'global' -Force
Set-Variable 'REQUIREMENTS' -Scope 'global' -Option 'ReadOnly' -Value $global:REQUIREMENTS

foreach ($requirement in $global:REQUIREMENTS) {
    Write-Debug "[REQUIREMENTS.json] $($requirement | Out-String)"

    if ($requirement.Import -eq '.' -and (Test-Path $requirement.Path)) {
        Write-Debug "[REQUIREMENTS.json] Importing: $($requirement.Path)"
        . $requirement.Path
    } elseif ($requirement.Import) {
        Write-Debug "[REQUIREMENTS.json] ``Import`` command: $($requirement.Import)"
        try {
            Invoke-Expression $requirement.Import
        } catch {
            Write-Debug "[REQUIREMENTS.json] `Import` failed: $_"
        }
    }

    $command_valid = $false
    try {
        if ($requirement.Command.Contains(' ')) {
            # Get-Command doesn't error if $requirement.Command contains a space.
            Throw('Commands should never contain a space.')
        }
        Get-Command $requirement.Command | Out-Null

        Write-Debug '[REQUIREMENTS.json] `Command` Successful'
        $command_valid = $true
    } catch {
        Write-Debug "[REQUIREMENTS.json] ``Command`` doesn't exist: $_"
        Write-Debug '[REQUIREMENTS.json] Trying it as expression ...'
        try {
            if (Resolve-Path $requirement.Command) {
                Write-Debug '[REQUIREMENTS.json] `Command` is a valid file.'
            } else {
                Invoke-Expression $requirement.Command | Out-Null
                Write-Debug '[REQUIREMENTS.json] Expression Successful'
            }

            $command_valid = $true
        } catch {
            if ($requirement.Path.EndsWith('\') -and (Test-Path $requirement.Path)) {
                Write-Debug "[REQUIREMENTS.json] ``Command`` expression failed: $_"
                Write-Debug '[REQUIREMENTS.json] Trying it from `Path` ...'
                Push-Location $requirement.Path
                
                try {
                    if (Resolve-Path $requirement.Command) {
                        Write-Debug '[REQUIREMENTS.json] `Command` is a valid file.'
                    } else {
                        Invoke-Expression $requirement.Command | Out-Null
                        Write-Debug '[REQUIREMENTS.json] Expression Successful'
                    }

                    $command_valid = $true
                } catch {
                    Write-Debug "[REQUIREMENTS.json] ``Command`` expression failed: $_"
                }

                Pop-Location
            } else {
                Write-Debug '[REQUIREMENTS.json] `Command` expression failed; will download the requirement ...'
            }
        }
    }

    if (-not $command_valid) {
        Write-Debug '[REQUIREMENTS.json] Downloading the requirement ...'
        if ($requirement.URL.EndsWith('.zip')) {
            Write-Debug '[REQUIREMENTS.json] URL is ZipFile'
            $zip_guid = [GUID]::NewGUID()

            Write-Debug "[REQUIREMENTS.json] Downloading to: ${env:Temp}\requirement_${zip_guid}.zip"
            Invoke-WebRequest $requirement.URL -OutFile "${env:Temp}\requirement_${zip_guid}.zip" -UseBasicParsing

            if (Test-Path (Split-Path $requirement.Path -Parent)) {
                Write-Debug '[REQUIREMENTS.json] Deleting current `Path` Parent'
                Remove-Item (Split-Path $requirement.Path -Parent) -Force -Recurse
            }

            if ($requirement.Path.EndsWith('\')) {
                if (Test-Path $requirement.Path) {
                    Write-Debug '[REQUIREMENTS.json] Deleting current `Path`'
                    Remove-Item $requirement.Path -Force -Recurse
                }

                $Parent = Split-Path $requirement.Path -Parent
            } else {
                if (Test-Path (Split-Path $requirement.Path -Parent)) {
                    Write-Debug '[REQUIREMENTS.json] Deleting current `Path` Parent'
                    Remove-Item (Split-Path $requirement.Path -Parent) -Force -Recurse
                }

                $Parent = Split-Path (Split-Path $requirement.Path -Parent) -Parent
            }
            
            if (-not (Test-Path $Parent)) {
                New-Item -ItemType Directory -Force -Path $Parent | %{ Write-Debug "Created Directory: $_" }
            }

            Add-Type -Assembly 'System.IO.Compression.FileSystem'
            Write-Debug "[REQUIREMENTS.json] Unzipping the ZipFile to: ${Parent}"
            [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path "${env:Temp}\requirement_${zip_guid}.zip"), (Resolve-Path $Parent))

            Write-Debug "[REQUIREMENTS.json] Deleting the ZipFile"
            Remove-Item "${env:Temp}\requirement_${zip_guid}.zip"
        } else {
            Write-Debug '[REQUIREMENTS.json] URL is File'
            $Parent = Split-Path $requirement.Path -Parent
            if (-not (Test-Path $Parent)) {
                New-Item -ItemType Directory -Force -Path $Parent | %{ Write-Debug "Created Directory: $_" }
            }

            Write-Debug '[REQUIREMENTS.json] Downloading to `Path`'
            Invoke-WebRequest $requirement.URL -OutFile $requirement.Path -UseBasicParsing
        }

        if ($requirement.Import -eq '.') {
            Write-Debug "[REQUIREMENTS.json] Importing: $($requirement.Path)"
            . $requirement.Path
        } elseif ($requirement.Import) {
            Write-Debug "[REQUIREMENTS.json] Import Command: $($requirement.Import)"
            Invoke-Expression $requirement.Import
        }
    }
}

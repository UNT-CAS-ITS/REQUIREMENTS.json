$ErrorActionPreference = 'Stop'

foreach ($requirement in (ConvertFrom-Json (Get-Content .\REQUIREMENTS.json | Out-String))) {
    Write-Debug "[REQUIREMENTS.json] $($requirement | Out-String)"

    $Command_f = if ($requirement.Command_f) { Invoke-Expression $requirement.Command_f } else { '' }
    $Command = $requirement.Command -f $Command_f
    Write-Debug "[REQUIREMENTS.json] Command: $Command"
    $URL_f = if ($requirement.URL_f) { Invoke-Expression $requirement.URL_f } else { '' }
    $URL = $requirement.URL -f $URL_f
    Write-Debug "[REQUIREMENTS.json] URL: $URL"
    $Path_f = if ($requirement.Path_f) { Invoke-Expression $requirement.Path_f } else { '' }
    $Path = $requirement.Path -f $Path_f
    Write-Debug "[REQUIREMENTS.json] Path: $Path"
    $Import_f = if ($requirement.Import_f) { Invoke-Expression $requirement.Import_f } else { '' }
    $Import = $requirement.Import -f $Import_f
    Write-Debug "[REQUIREMENTS.json] Import: $Import"

    if ($requirement.Import -eq '.' -and (Test-Path $Path)) {
        Write-Debug "[REQUIREMENTS.json] Importing: ${Path}"
        . $Path
    } elseif ($requirement.Import) {
        Write-Debug "[REQUIREMENTS.json] ``Import`` command: ${Import}"
        try {
            Invoke-Expression $Import
        } catch {
            Write-Debug "[REQUIREMENTS.json] `Import` failed: $_"
        }
    }

    $command_valid = $false
    try {
        if ($Command.Contains(' ')) {
            # Get-Command doesn't error if $Command contains a space.
            Throw('Commands should never contain a space.')
        }
        Get-Command $Command | Out-Null

        Write-Debug '[REQUIREMENTS.json] `Command` Successful'
        $command_valid = $true
    } catch {
        Write-Debug "[REQUIREMENTS.json] ``Command`` doesn't exist: $_"
        Write-Debug '[REQUIREMENTS.json] Trying it as expression ...'
        try {
            if (Resolve-Path $Command) {
                Write-Debug '[REQUIREMENTS.json] `Command` is a valid file.'
            } else {
                Invoke-Expression $Command | Out-Null
                Write-Debug '[REQUIREMENTS.json] Expression Successful'
            }

            $command_valid = $true
        } catch {
            if ($Path.EndsWith('\') -and (Test-Path $Path)) {
                Write-Debug "[REQUIREMENTS.json] ``Command`` expression failed: $_"
                Write-Debug '[REQUIREMENTS.json] Trying it from `Path` ...'
                Push-Location $Path
                
                try {
                    if (Resolve-Path $Command) {
                        Write-Debug '[REQUIREMENTS.json] `Command` is a valid file.'
                    } else {
                        Invoke-Expression $Command | Out-Null
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
        if ($URL.EndsWith('.zip')) {
            Write-Debug '[REQUIREMENTS.json] URL is ZipFile'
            $zip_guid = [GUID]::NewGUID()

            Write-Debug "[REQUIREMENTS.json] Downloading to: ${env:Temp}\requirement_${zip_guid}.zip"
            Invoke-WebRequest $URL -OutFile "${env:Temp}\requirement_${zip_guid}.zip" -UseBasicParsing

            if (Test-Path (Split-Path $Path -Parent)) {
                Write-Debug '[REQUIREMENTS.json] Deleting current `Path` Parent'
                Remove-Item (Split-Path $Path -Parent) -Force -Recurse
            }

            if ($Path.EndsWith('\')) {
                if (Test-Path $Path) {
                    Write-Debug '[REQUIREMENTS.json] Deleting current `Path`'
                    Remove-Item $Path -Force -Recurse
                }

                $Parent = Split-Path $Path -Parent
            } else {
                if (Test-Path (Split-Path $Path -Parent)) {
                    Write-Debug '[REQUIREMENTS.json] Deleting current `Path` Parent'
                    Remove-Item (Split-Path $Path -Parent) -Force -Recurse
                }

                $Parent = Split-Path (Split-Path $Path -Parent) -Parent
            }
            
            if (-not (Test-Path $Parent)) {
                New-Item -ItemType Directory -Force -Path $Parent | Write-Debug
            }

            Add-Type -Assembly 'System.IO.Compression.FileSystem'
            Write-Debug "[REQUIREMENTS.json] Unzipping the ZipFile to: ${Parent}"
            [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path "${env:Temp}\requirement_${zip_guid}.zip"), (Resolve-Path $Parent))

            Write-Debug "[REQUIREMENTS.json] Deleting the ZipFile"
            Remove-Item "${env:Temp}\requirement_${zip_guid}.zip"
        } else {
            Write-Debug '[REQUIREMENTS.json] URL is File'
            $Parent = Split-Path $Path -Parent
            New-Item -ItemType Directory -Force -Path $Parent | Write-Debug

            Write-Debug '[REQUIREMENTS.json] Downloading to `Path`'
            Invoke-WebRequest $URL -OutFile $Path -UseBasicParsing
        }

        if ($requirement.Import -eq '.') {
            Write-Debug "[REQUIREMENTS.json] Importing: ${Path}"
            . $Path
        } elseif ($requirement.Import) {
            Write-Debug "[REQUIREMENTS.json] Import Command: ${Import}"
            Invoke-Expression $Import
        }
    }
}
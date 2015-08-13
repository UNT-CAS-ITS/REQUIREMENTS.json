foreach ($requirement in (ConvertFrom-Json (Get-Content .\REQUIREMENTS.json | Out-String))) {
    Write-Debug ($requirement | Out-String)
    if (-not (Get-Command $requirement.Command -ErrorAction Ignore)) {
        Write-Debug ($requirement | Out-String)
        if (-not (Test-Path ($requirement.Path -f (Invoke-Expression $requirement.Path_f)) -ErrorAction Ignore)) {
            Invoke-WebRequest ($requirement.URL -f (Invoke-Expression $requirement.URL_f)) -OutFile 'requirement.zip' -UseBasicParsing

            $Parent = (Split-Path (Split-Path ($requirement.Path -f (Invoke-Expression $requirement.Path_f)) -Parent) -Parent)
            New-Item -ItemType Directory -Force -Path $Parent | Write-Debug

            Add-Type -Assembly 'System.IO.Compression.FileSystem'
            [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path 'requirement.zip'), (Resolve-Path $Parent))
            
            Remove-Item 'requirement.zip'
        }

        . ($requirement.Path -f (Invoke-Expression $requirement.Path_f))
    }
}

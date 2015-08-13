foreach ($requirement in (ConvertFrom-Json (Get-Content .\REQUIREMENTS.json | Out-String))) {
    if (-not (Get-Command $requirement.Command -ErrorAction Ignore)) {
        if (-not (Test-Path ($requirement.Path -f (Invoke-Expression $requirement.Path_f)) -ErrorAction Ignore)) {
            Invoke-WebRequest ($requirement.URL -f (Invoke-Expression $requirement.URL_f)) -OutFile 'requirement.zip' -UseBasicParsing
            Add-Type -Assembly 'System.IO.Compression.FileSystem'
            [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path 'requirement.zip'), (Get-Location))
            Remove-Item 'requirement.zip'
        }

        . ($requirement.Path -f (Invoke-Expression $requirement.Path_f))
    }
}

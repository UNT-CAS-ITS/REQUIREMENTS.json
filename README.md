# REQUIREMENTS.json

This is a simple script that reads a REQUIREMENTS document from a REQUIREMENTS.json file and does the necessary installs.

# Usage

Just put the code from `requirements.ps1` at the top of your script and make a `REQUIREMENTS.json` file.

## Pull from GitHub

```posh
Invoke-Expression (Invoke-WebRequest 'https://raw.githubusercontent.com/UNT-CAS-ITS/REQUIREMENTS.json/v1.1/requirements.ps1' -UseBasicParsing).Content
```

Like obnoxiously short versions of commands? I've got you covered:

```posh
iex (iwr 'https://goo.gl/swuuKv' -useb).Content
```

# Sample REQUIREMENTS.json

The `URL_f` and `Path_f` keys are optional. Use them the to format (`-f`) the corresponding keys. The `$requirement` variable refers to the current requirement; this is useful for injecting the value of one key into the value of another. Only `URL` and `Path` use `-f` operators.

## Work from Local

```json
[
	{
		"Command": "Write-Log",
		"Version": "1.1.1",
		"URL": "https://github.com/UNT-CAS-ITS/Write-Log/archive/v{0}.zip",
		"URL_f": "$requirement.Version",
		"Path": ".\\Write-Log-{1}\\Write-Log.ps1",
		"Path_f": "$requirement.Version"
	}
]
```

## Download everything to `$env:Temp`.

```json
[
	{
		"Command": "Write-Log",
		"Version": "1.1.1",
		"URL": "https://github.com/UNT-CAS-ITS/Write-Log/archive/v{0}.zip",
		"URL_f": "$requirement.Version",
		"Path": "{0}\\github_release_cache\\Write-Log-{1}\\Write-Log.ps1",
		"Path_f": "@($env:Temp , $requirement.Version)"
	}
]
```

**Note:** the following will *not* work because the `$env:Temp` variable will *not* be evaluated:

```json
"Path": "${env:Temp}\\github_release_cache\\Write-Log-{0}\\Write-Log.ps1",
"Path_f": "$requirement.Version"
```

The final path would be (notice the single quotes; paste it into powershell if you're confused):

```posh
'${env:Temp}\github_release_cache\Write-Log-1.1.1\Write-Log.ps1'
```

# REQUIREMENTS.json

This is a simple script that reads a REQUIREMENTS document from a REQUIREMENTS.json file and does the necessary installs.

Just put the code from `requirements.ps1` at the top of your script and make a `REQUIREMENTS.json` file.

# Sample REQUIREMENTS.json

```json
[
	{
		"Command": "Write-Log",
		"Version": "1.1.1",
		"URL": "https://github.com/UNT-CAS-ITS/Write-Log/archive/v{0}.zip",
		"URL_f": "$requirement.Version",
		"Path": ".\\Write-Log-{0}\\Write-Log.ps1",
		"Path_f": "$requirement.Version"
	}
]
```

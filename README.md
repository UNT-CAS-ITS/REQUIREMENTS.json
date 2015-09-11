REQUIREMENTS.json is a pre-requisites downloader and extractor (given a .zip). Think of it like Python's REQUIREMENTS.txt, but without requiring [pip, a central repository of modules/extensions](https://pypi.python.org).

All functionality is done in a [single, simple script](requirements.ps1). This script reads your REQUIREMENTS.json file and downloads (if not already present at the location that you specify), imports, and verifies that your script's requirements are available for use by your script.

The wiki contains a [more complete explanation](../../wiki/Home).

# Quick Start

Add this line to the top of your script (although, I prefer [this method](../../wiki/Usage#pull-from-github-and-archive)):

```powershell
Invoke-Expression (Invoke-WebRequest 'https://raw.githubusercontent.com/UNT-CAS-ITS/REQUIREMENTS.json/v1.2/requirements.ps1' -UseBasicParsing).Content
```

Create a `REQUIREMENTS.json` file and put it in the same directory as your script.

# Example REQUIREMENTS.json

```json
[
    {
        "Command": "Get-FolderItem",
        "URL": "https://gallery.technet.microsoft.com/scriptcenter/Get-Deeply-Nested-Files-a2148fd7/file/107404/1/Get-FolderItem.ps1",
        "Path": ".\\Get-FolderItem.ps1",
        "Import": "."
    }
]
```

More [usage examples are available in the wiki](../../wiki/Usage). Also, take a look at the [global:REQUIREMENTS wiki](../../wiki/global:REQUIREMENTS) to see an example of how you can easily use the information from the *REQUIREMENTS.json* in your script. Also, checkout the [information about required, optional, and custom keys](../../wiki/Keys).

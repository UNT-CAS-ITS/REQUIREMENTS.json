This is a simple script that reads a REQUIREMENTS document from a REQUIREMENTS.json file and does the necessary installs.

Example `REQUIREMENTS.json`:

```json
[
    {
        "Command": "Get-FolderItem",
        "Synopsis": "Lists all files under a specified folder regardless of character limitation on path depth.",
        "Source": "https://gallery.technet.microsoft.com/scriptcenter/Get-Deeply-Nested-Files-a2148fd7",
        "Version": "2014.01.16",
        "URL": "https://gallery.technet.microsoft.com/scriptcenter/Get-Deeply-Nested-Files-a2148fd7/file/107404/1/Get-FolderItem.ps1",
        "Path": "{0}\\github_release_cache\\Get-FolderItem-{1}\\Get-FolderItem.ps1",
        "Path_f": "@($env:Temp , $requirement.Version)",
        "Import": "."
    }
]
```

Check out the wiki on this repo for usage and information about required, optional, and custom keys.

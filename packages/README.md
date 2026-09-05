# Package lists

`scoop.json` and `winget.json` are exported snapshots of what is installed on
this machine. They make Windows genuinely rebuildable: the profile comes back
from the repository, the applications come back from these two files.

## Restore on a new machine

```powershell
scoop import packages\scoop.json
winget import -i packages\winget.json
```

`bootstrap.ps1` does not run these for you. They install hundreds of megabytes
and take a long time, so the choice of when stays yours.

## Re-export after installing something

```powershell
scoop export | Out-File -Encoding utf8 packages\scoop.json
winget export -o packages\winget.json
git add packages/
git commit -m "chore: update package lists"
```

`winget export` prints a warning for each installed application that has no
winget source, such as manually installed or Store applications. That is
expected; those entries are simply left out of the file.

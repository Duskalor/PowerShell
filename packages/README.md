# Package lists

Configuration comes back from this repository. Applications come back from here.

| File | What it holds | Who reads it |
|------|---------------|--------------|
| `winget-core.json` | The toolchain the profile actually calls: git, gh, pwsh, alacritty, zellij, rg, fd, bat, eza, fzf, zoxide, lazygit, node, code, claude, msys2 | `install.ps1` by default |
| `winget.json` | Full snapshot of this machine — games, office suites, redistributables and all | `install.ps1 -AllPackages` |
| `scoop.json` | The few tools installed through scoop | by hand |

## Why two winget files

`winget export` writes down everything installed, which on a personal machine
means Steam, Battle.net, Adobe Acrobat and a dozen Visual C++ redistributables.
That is the right artifact for rebuilding *this* machine and the wrong one for
walking onto a new machine and getting a working terminal in a few minutes.

`winget-core.json` is the curated half: install it and every command the profile
defines resolves. Every identifier in it was taken from a real export or
verified against the winget package repository, so nothing in it is a guess.

## Restore

```powershell
.\install.ps1                 # winget-core.json, plus font, engram and links
.\install.ps1 -AllPackages    # the full snapshot instead
```

By hand, without the installer:

```powershell
winget import -i packages\winget-core.json --accept-package-agreements --accept-source-agreements --ignore-unavailable
scoop import packages\scoop.json
```

## Re-export after installing something

```powershell
winget export -o packages\winget.json
scoop export | Out-File -Encoding utf8 packages\scoop.json
git add packages/
git commit -m "chore: update package lists"
```

`winget export` prints a warning for each installed application that has no
winget source, such as manually installed or Store applications. That is
expected; those entries are simply left out of the file.

Re-exporting rewrites `winget.json` only. `winget-core.json` is curated by hand,
so add the new identifier to it yourself when the tool is something the profile
depends on.

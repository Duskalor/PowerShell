# Package lists

Configuration comes back from this repository. Applications come back from here.

| File | What it holds | Who reads it |
|------|---------------|--------------|
| `winget-core.json` | The toolchain the profile and the agents actually call: git, gh, pwsh, alacritty, zellij, rg, fd, bat, eza, fzf, zoxide, lazygit, node, code, claude desktop and CLI, opencode, python, pnpm, bun, jq | `install.ps1` by default |
| `winget.json` | Full snapshot of this machine — games, office suites, redistributables and all | `install.ps1 -AllPackages` |
| `scoop.json` | The few tools installed through scoop | by hand |
| `vscode-extensions.txt` | The 87 VS Code extensions, one identifier per line | `install.ps1` |
| `claude-plugins.txt` | The Claude Code marketplaces and the plugins installed from them | `install.ps1` |

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
Get-Content packages\vscode-extensions.txt | ForEach-Object { code --install-extension $_ }
```

Claude Code plugins, marketplaces first, because
`plugin install <name>@<marketplace>` can only resolve a marketplace that was
added already:

```powershell
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add Gentleman-Programming/engram
claude plugin install superpowers@claude-plugins-official
```

## Why the extensions are a flat list

VS Code has no import command and no manifest format: `--install-extension`
takes one identifier at a time, and the only thing it needs is the identifier.
A plain text file is therefore the whole artifact, and it stays diffable - a
commit shows exactly which extension was added or dropped, which a JSON export
of the same data would bury in punctuation.

The list carries no versions on purpose. Pinning an extension to the version
that happened to be installed would hand a new machine an old build of
something the marketplace keeps current anyway, and the loop above would fail
outright once that version is delisted.

## Why the plugins are a list and not a link

`~/.claude/plugins` is 65 MB of marketplace git checkouts plus an install cache
keyed by commit sha. That is a cache, not configuration, which is why
`manifest.psd1` leaves it out of the entry by entry allowlist for `~/.claude` —
see [Why the Claude Code plugins are not a
link](../README.md#why-the-claude-code-plugins-are-not-a-link).

The file therefore records intent rather than state. It carries two kinds of
line because the two commands are different and ordered:

```
marketplace <owner/repo>        claude plugin marketplace add
plugin      <name@marketplace>  claude plugin install
```

`marketplace add` derives the marketplace name from the last segment of the
repository, which is why the suffix of every plugin id matches a repo name
above. Rename one without the other and the id stops resolving.

No versions here either, for the reason the extensions carry none: the pinned
sha of a plugin that the marketplace keeps current is a worse starting point
than whatever is current, and it would be a dead reference soon enough.

The file carries no comments, for the same reason the extension list does not:
the re-export below rewrites it whole, so anything hand written in it would be
lost the next time a plugin is added. This section is where the explanation
lives instead.

### Account synced plugins are not in the list

`claude plugin list` also reports plugins with `"scope": "synced"`, installed
under `~/.claude/plugins/synced/<account id>_...` and belonging to no configured
marketplace. Those come down from the claude.ai account on sign in, so they
restore themselves and there is nothing for this file to record. Worse, writing
one here would be actively wrong: `plugin install <name>@synced` has no
marketplace to resolve against and cannot succeed. The re-export below filters
them out, which is the only reason that filter is there.

## Re-export after installing something

```powershell
winget export -o packages\winget.json
scoop export | Out-File -Encoding utf8 packages\scoop.json
code --list-extensions | Sort-Object | Set-Content packages\vscode-extensions.txt
# Claude Code plugins. Account synced plugins are excluded - see above.
@(
  (claude plugin marketplace list --json | ConvertFrom-Json |
     ForEach-Object { "marketplace $($_.repo)" })
  ''
  (claude plugin list --json | ConvertFrom-Json |
     Where-Object { $_.scope -ne 'synced' } |
     ForEach-Object { "plugin      $($_.id)" })
) | Set-Content packages\claude-plugins.txt
git add packages/
git commit -m "chore: update package lists"
```

`winget export` prints a warning for each installed application that has no
winget source, such as manually installed or Store applications. That is
expected; those entries are simply left out of the file.

Re-exporting rewrites `winget.json` only. `winget-core.json` is curated by hand,
so add the new identifier to it yourself when the tool is something the profile
depends on.

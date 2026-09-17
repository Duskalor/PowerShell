# Dev Environment — Windows

Every configuration file this machine runs on, in one repository.
Terminal chain: **Alacritty → Zellij → pwsh**

The repository holds the only copy of each config. Almost everything under
`~/.config`, `~/.claude` and `%APPDATA%` is a symbolic link pointing back here,
so editing a file in either place edits the same bytes. There is no export step
to remember.

Three configs cannot work that way, because they contain absolute paths that
include the Windows user name and the tools reading them do not resolve a bare
command from PATH. Those are stored as `.template` files with tokens and
written out as real files — see [Two mechanisms](#two-mechanisms).

> Run `cmds` in any terminal to see all available commands.

---

## Fresh machine

One line, on a machine with nothing on it:

```powershell
irm https://raw.githubusercontent.com/Duskalor/PowerShell/main/install.ps1 | iex
```

Read the plan first if you prefer — nothing is written:

```powershell
irm https://raw.githubusercontent.com/Duskalor/PowerShell/main/install.ps1 -OutFile install.ps1
.\install.ps1 -DryRun
```

`install.ps1` runs under the Windows PowerShell 5.1 that ships with Windows, so
there is nothing to install before it. In order it:

1. checks winget is present and that this shell may create symbolic links
2. installs **git** and **PowerShell 7** if they are missing
3. clones this repository into the real PowerShell profile directory —
   `[Environment]::GetFolderPath('MyDocuments')`, not `$HOME\Documents`, because
   OneDrive redirects Documents on most machines and a clone in the wrong place
   links every config correctly into a profile that never loads
4. installs the toolchain from `packages/winget-core.json`
5. installs **IosevkaTerm Nerd Font** for the current user, no elevation needed
6. installs **engram** into `~\bin` and puts `~\bin` on PATH
7. hands over to `bootstrap.ps1`, which links every config

Every step checks before it acts, so running it again repairs a machine instead
of duplicating anything.

| Flag | Effect |
|------|--------|
| `-DryRun` | report every step, change nothing |
| `-AllPackages` | restore `packages/winget.json`, the full machine snapshot, instead of the curated toolchain |
| `-SkipPackages` | link the configuration, install no applications |
| `-SkipFont` / `-SkipEngram` | leave those alone |

### Already have git and a clone

```powershell
git clone https://github.com/Duskalor/PowerShell.git "$HOME\Documents\PowerShell"
cd "$HOME\Documents\PowerShell"
.\bootstrap.ps1          # links configuration only, installs nothing
```

Anything already sitting at a destination is moved into `.backup/<timestamp>/`
before the link is made, so running this on a machine that is already configured
will not lose work.

### Symbolic links need permission

Windows only lets a normal user create symbolic links when **Developer Mode** is
on. Turn it on once:

> Settings → System → For developers → Developer Mode → **On**

The alternative is running from an Administrator terminal. `install.ps1` and
`bootstrap.ps1` both check for this up front and stop with instructions rather
than failing on every file.

---

## Keeping it in sync

```powershell
.\sync.ps1 -Check   # report drift, change nothing
.\sync.ps1          # repair it
```

Run this when something feels off, or wire `sync.ps1 -Check` into your prompt.

**Why this script exists.** Some applications save a file by writing a temporary
copy and renaming it over the original. That silently replaces the symbolic link
with a regular file. Claude Code does exactly this when settings change from
inside the tool. The machine keeps working, nothing looks broken, and the
repository quietly stops receiving changes.

`sync.ps1` finds those cases and treats the machine as the source of truth: the
newer content is copied **into** the repository first, then the link is
restored. Local edits are never discarded. Afterwards, review and commit:

```powershell
git diff
```

---

## Two mechanisms

| | Linked | Rendered |
|---|---|---|
| Entries | 25 | 3 |
| What is on the machine | a symbolic link into this repository | a real file written from a `.template` |
| Edit on the machine | is an edit to the repository, immediately | needs `sync.ps1` to travel back |
| Declared in | `manifest.psd1` → `Links` | `manifest.psd1` → `Rendered` |

Linking is the default and the better mechanism. Rendering exists for the three
configs that cannot be identical on two machines:

| Config | Why it cannot be a link |
|---|---|
| `alacritty.toml` | the absolute path to the `zellij.exe` it launches as the shell |
| `zellij/config.kdl` | the same binary, plus two layout paths |
| `opencode.json` | ten agent prompt files and one MCP command |

None of those three tools resolves a bare command name from PATH, so the path
has to be absolute — and an absolute path under `C:\Users\<you>` is wrong on
any machine but the one it was written on.

### Tokens

A template holds tokens instead. Each comes in three spellings because the file
formats disagree on how a Windows path is written:

| Token | Expands to | Used by |
|---|---|---|
| `{HOME}` | `C:\Users\you` | plain strings |
| `{HOME/}` | `C:/Users/you` | zellij, opencode |
| `{HOME\\}` | `C:\\Users\\you` | JSON and TOML string literals |

`HOME`, `APPDATA` and `LOCALAPPDATA` are available. Longest expansion wins, so
`{LOCALAPPDATA}` is never mistaken for `{HOME}\AppData\Local`.

### The way back

A rendered file is an ordinary file, so an edit made on the machine does not
reach the repository on its own. That is the exact drift this repository was
built to prevent, so `sync.ps1` covers it: it compares each rendered file
against what its template produces, and when they differ it runs the expansion
**backwards** — this machine's own paths become tokens again — and writes the
result into the template.

```powershell
.\sync.ps1 -Check   # "drifted — edited on this machine, the template is behind"
.\sync.ps1          # "rescued — machine edits tokenized back into the template"
```

Nothing is lost in either direction. Edit the rendered file or edit the
template, whichever is closer to hand.

### Adding another one

Move its row in `manifest.psd1` from `Links` to `Rendered`, then let the
inverse function write the template for you rather than hand-editing paths:

```powershell
. .\lib\dotfiles.ps1
$text = Read-DotfilesText .\config\foo\bar.toml
Write-DotfilesText -Path .\config\foo\bar.toml.template -Text (ConvertTo-DotfilesTemplateText $text)
git rm .\config\foo\bar.toml
.\bootstrap.ps1
```

---

## What is here

```
├── install.ps1                      bare machine to configured, in one command
├── bootstrap.ps1                    set the machine up from the repo
├── sync.ps1                         detect and repair links and template drift
├── manifest.psd1                    what is linked or rendered where — the source of truth
├── lib/dotfiles.ps1                 shared helpers for both scripts
├── Microsoft.PowerShell_profile.ps1 the pwsh profile (already in place, see below)
├── home/                            .gitconfig, .wezterm.lua
├── config/
│   ├── alacritty/                   alacritty.toml.template, alacritty-wsl.toml
│   ├── zellij/                      config.kdl.template, layouts/
│   ├── claude/                      settings.json, CLAUDE.md, agents/,
│   │                                commands/, skills/, output-styles/,
│   │                                statusline-command.sh
│   ├── opencode/                    opencode.json.template, AGENTS.md, agents/,
│   │                                commands/, plugins/, prompts/, skills/
│   ├── agents/skills/               shared agent skills
│   ├── gga/                         Gentleman Guardian Angel
│   └── git/ignore                   global gitignore
├── packages/                        winget-core.json, winget.json, scoop.json
├── Scripts/                         standalone helper scripts
└── Modules/                         vendored PowerShell modules
```

**The profile needs no link.** This repository lives at
`~\Documents\PowerShell`, which is already PowerShell 7's `$PROFILE` directory.
Cloning it puts `Microsoft.PowerShell_profile.ps1` exactly where pwsh looks.

### Adding a new config

Copy the file into `config/`, add one row to `manifest.psd1`, run `.\sync.ps1`.
Nothing else changes — both scripts read the manifest.

---

## What is deliberately not here

Configuration is committed. Caches, history and downloaded binaries are not —
they are rebuilt by the tools that own them.

| Excluded | Size | Restored by |
|----------|------|-------------|
| `~/.claude/projects`, `file-history`, `cache`, `sessions` | ~300 MB | rebuilt as you work |
| `~/.claude/plugins` | 65 MB | Claude Code plugin install |
| `~/.config/opencode/node_modules` | 136 MB | `npm install` |
| `~/.config/zellij/plugins` | 8 MB | downloaded `.wasm`, fetched on demand |

Directories that mix configuration with cache are linked **entry by entry**,
never as a whole. That is why `manifest.psd1` lists `config/claude/settings.json`
rather than `config/claude`.

### Machine specific values

`~/.claude/settings.local.json` is never linked and never committed. Tokens,
project references and per machine MCP servers belong there. `bootstrap.ps1`
seeds it from `config/claude/settings.local.json.example` on a fresh machine and
leaves an existing one untouched.

**This repository is public.** Before committing a config, check it for anything
you would not publish.

### Hardcoded paths

There is nothing left to fix by hand. The three configs that carried absolute
paths with the Windows user name are rendered from templates — see
[Two mechanisms](#two-mechanisms) — so bootstrap writes the right paths for
whatever machine it runs on.

Two files still name this machine and are deliberately left as they are:

| File | Why it is fine |
|------|----------------|
| `config/claude/statusline-command.sh` | the absolute Python path is an `elif` branch, reached only after the PATH lookup fails |
| `config/opencode/plugins/engram.ts` | `process.env.ENGRAM_BIN ?? Bun.which("engram") ?? <path>` — the path is the last resort |

To confirm nothing has crept back in:

```powershell
rg -F "C:\Users" config home
```

Anything that turns up in a `Links` entry is a bug. Move it to `Rendered`.

---

## Commands Reference

### Tools (Rust-based)

| Command | Tool | Description |
|---------|------|-------------|
| `z <query>` | zoxide | Smart `cd` — learns your most visited dirs |
| `zi` | zoxide | Interactive dir picker (uses fzf) |
| `ls` | eza | File listing with icons |
| `ll` | eza | Detailed listing |
| `la` | eza | Listing with hidden files |
| `lt` | eza | Tree view (2 levels, ignores node_modules/.git/dist) |
| `lst` | eza | Full tree (ignores node_modules/.git/dist) |
| `cat <file>` | bat | File viewer with syntax highlighting |
| `fdt <text>` | ripgrep | Search text inside files |
| `fda <name>` | fd | Search files and folders |

### Git

| Command | Description |
|---------|-------------|
| `lg` | Open lazygit (visual TUI) |
| `gs` | git status |
| `ga <files>` | git add |
| `gc 'msg'` | git commit -m |
| `gp` | git push |
| `gpl` | git pull |
| `gl` | git log (graph, last 10) |
| `gsw <name>` | git switch |
| `gswc <name>` | git switch -c (new branch) |
| `gb` | list branches |
| `gbd <name>` | delete branch (safe) |
| `gbD <name>` | delete branch (force) |
| `gm <branch>` | git merge |
| `grs <file>` | git restore |
| `gst` | git stash |
| `gstp` | git stash pop |

### Navigation

| Command | Path |
|---------|------|
| `d` | `~/Documents/Proyects` |
| `pr` | React |
| `fr` | frontEndMentor |
| `n` | Node |
| `ne` | Nextjs |
| `nes` | nestjs |
| `as` | astro |
| `js` | javascript |
| `l` | Laravel |
| `p` | PHP |
| `mono` | MonoRepo |
| `power` | PowerShell profile + VSCode |
| `w` | Open current folder in Explorer |

### Project Scaffolding

| Command | What it does |
|---------|-------------|
| `vite <name>` | Vite project + install + VSCode + dev |
| `vitet <name>` | Vite + Tailwind + install + VSCode + dev |
| `next <name>` | Next.js project + VSCode + dev |
| `astro <name>` | Astro project + VSCode + dev |
| `dev` | `pnpm run dev` |

### Utilities

| Command | What it does |
|---------|-------------|
| `cf <path> <files>` | Create folder + files (`.ts` default) |
| `newdb` | Spin up Postgres via Docker |
| `rmj [name]` | Parse judicial HTML to searchable TXT + HTML |
| `cmds` | Show all profile commands (`ghelp` is an alias) |

### Zellij (inside Zellij only)

| Keybinding | What it does |
|------------|-------------|
| `Alt+F` | Toggle / create floating pane at current dir |
| `Alt+F, f` | Force create new floating pane |

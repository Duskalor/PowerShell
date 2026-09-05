# Dev Environment — Windows

Every configuration file this machine runs on, in one repository.
Terminal chain: **Alacritty → Zellij → pwsh**

The repository holds the only copy of each config. Everything under `~/.config`,
`~/.claude` and `%APPDATA%` is a symbolic link pointing back here, so editing a
file in either place edits the same bytes. There is no export step to remember
and no way for the repository to fall behind.

> Run `cmds` in any terminal to see all available commands.

---

## Fresh machine

```powershell
git clone https://github.com/Duskalor/PowerShell.git "$HOME\Documents\PowerShell"
cd "$HOME\Documents\PowerShell"
.\bootstrap.ps1
```

That is the whole setup. `bootstrap.ps1` reads `manifest.psd1` and links every
config into place.

Preview it first if you like — nothing is written:

```powershell
.\bootstrap.ps1 -DryRun
```

Anything already sitting at a destination is moved into `.backup/<timestamp>/`
before the link is made, so running this on a machine that is already configured
will not lose work.

### Symbolic links need permission

Windows only lets a normal user create symbolic links when **Developer Mode** is
on. Turn it on once:

> Settings → System → For developers → Developer Mode → **On**

The alternative is running `bootstrap.ps1` from an Administrator terminal.
`bootstrap.ps1` checks for this up front and stops with instructions rather than
failing on every file.

### Four things bootstrap cannot do for you

| Step | Command |
|------|---------|
| Install **IosevkaTerm Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com/font-downloads) — extract, select all `.ttf`, right click → Install for all users |
| Restore Scoop packages | `scoop import packages\scoop.json` |
| Restore Winget packages | `winget import -i packages\winget.json` |
| Install the Engram binary | Download `engram-windows-x64.exe` from [releases](https://github.com/Gentleman-Programming/engram/releases), save as `~\bin\engram.exe`, add `~\bin` to PATH |

The font has to be installed by the operating system, and the package lists
install hundreds of megabytes that do not belong in a git repository.

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

## What is here

```
├── bootstrap.ps1                    set the machine up from the repo
├── sync.ps1                         detect and repair broken links
├── manifest.psd1                    what gets linked where — the source of truth
├── lib/dotfiles.ps1                 shared helpers for both scripts
├── Microsoft.PowerShell_profile.ps1 the pwsh profile (already in place, see below)
├── home/                            .gitconfig, .wezterm.lua
├── config/
│   ├── alacritty/                   alacritty.toml, alacritty-wsl.toml
│   ├── zellij/                      config.kdl, layouts/
│   ├── claude/                      settings.json, CLAUDE.md, agents/,
│   │                                commands/, skills/, output-styles/,
│   │                                statusline-command.sh
│   ├── opencode/                    opencode.json, AGENTS.md, agents/,
│   │                                commands/, plugins/, prompts/, skills/
│   ├── agents/skills/               shared agent skills
│   ├── gga/                         Gentleman Guardian Angel
│   └── git/ignore                   global gitignore
├── packages/                        scoop.json, winget.json
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

Several configs contain absolute paths that include the Windows user name. They
are committed as they are, because that is what this machine runs. On a machine
whose user folder is not `C:\Users\Paul Cruz`, fix these after bootstrap:

| File | What to change |
|------|----------------|
| `config/opencode/opencode.json` | 10 `{file:...}` prompt paths, and the `pc-cotizador` MCP command |
| `config/claude/settings.json` | the `engram` MCP command path |
| `config/alacritty/alacritty.toml` | `program` — the path to `zellij.exe` |
| `config/zellij/config.kdl` | two `Run` keybindings pointing at `zellij.exe` and `layouts/` |

Find them all at once:

```powershell
rg -F "C:\Users" config
```

`config/claude/statusline-command.sh` and `config/opencode/plugins/engram.ts`
also name absolute paths, but both fall back to a PATH lookup first, so they
keep working without edits.

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

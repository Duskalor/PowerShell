# PowerShell Profile — Dev Environment

PowerShell 7 profile for Windows with full dev environment setup.
Terminal chain: **Alacritty → Zellij → pwsh**

> Run `cmds` in any terminal to see all available commands.

---

## Fresh Machine Setup

Complete setup in order. Every step is required.

---

### 1. Clone the profile

```powershell
git clone https://github.com/Duskalor/PowerShell.git "$HOME\Documents\PowerShell"
```

---

### 2. Font — IosevkaTerm Nerd Font

Download and install manually — this is required for icons to render correctly.

- Go to: https://www.nerdfonts.com/font-downloads
- Search for **IosevkaTerm Nerd Font**
- Extract and install all `.ttf` files (right-click → Install for all users)

---

### 3. CLI tools via winget

```powershell
# Terminal
winget install Alacritty.Alacritty
winget install Zellij.Zellij

# Shell tools (Rust-based)
winget install ajeetdsouza.zoxide
winget install sharkdp.bat
winget install eza-community.eza
winget install BurntSushi.ripgrep.MSVC
winget install sharkdp.fd
winget install junegunn.fzf
winget install JesseDuffield.lazygit
```

---

### 4. PowerShell modules

```powershell
Install-Module Terminal-Icons -Scope CurrentUser -Force
Install-Module PSReadLine -Scope CurrentUser -Force
```

---

### 5. Alacritty config

```powershell
New-Item -ItemType Directory -Path "$HOME\AppData\Roaming\alacritty" -Force | Out-Null
Copy-Item "$HOME\Documents\PowerShell\alacritty.toml" "$HOME\AppData\Roaming\alacritty\alacritty.toml"
```

The config sets:
- Font: `IosevkaTerm NF` size 16
- Shell: `zellij.exe` (Alacritty launches Zellij directly)
- Opacity: 90%
- Color scheme: dark with lavender accents

---

### 6. Zellij config

```powershell
New-Item -ItemType Directory -Path "$HOME\.config\zellij" -Force | Out-Null
Copy-Item -Recurse "$HOME\Documents\PowerShell\.config\zellij\*" "$HOME\.config\zellij\"
```

The config sets:
- Default shell: `pwsh`
- Custom keybinds (vim-style navigation)
- Plugins: `zjstatus` (statusbar), `zellij_forgot` (keybind helper)
- Layouts: `work.kdl`, `work_vertical.kdl`, `work_oldWorld.kdl`

---

### 7. Claude Code

#### 7a. Install Claude Code

```powershell
winget install Anthropic.Claude
# or via npm:
npm install -g @anthropic-ai/claude-code
```

#### 7b. Engram binary

Engram is a persistent memory MCP server. Download the binary:

- Go to: https://github.com/Gentleman-Programming/engram/releases
- Download `engram-windows-x64.exe`
- Place it at: `C:\Users\<you>\bin\engram.exe`
- Make sure `C:\Users\<you>\bin` is in your PATH

#### 7c. Copy global config files

```powershell
# Create .claude directory
New-Item -ItemType Directory -Path "$HOME\.claude" -Force | Out-Null

# Copy global settings
Copy-Item "$HOME\Documents\PowerShell\.claude\settings.json" "$HOME\.claude\settings.json"

# Copy CLAUDE.md (global instructions)
Copy-Item "$HOME\Documents\PowerShell\.claude\CLAUDE.md" "$HOME\.claude\CLAUDE.md"
```

#### 7d. Install plugins

Open a terminal and run Claude Code once, then install:

```powershell
claude
# Inside Claude Code, run:
# /plugins install engram@Gentleman-Programming/engram
# /plugins install superpowers@claude-plugins-official
# /plugins install context7@claude-plugins-official
# /plugins install frontend-design@claude-plugins-official
```

Or add them directly to `settings.json` (already included in the copied file):

```json
"enabledPlugins": {
  "engram@engram": true,
  "frontend-design@claude-plugins-official": true,
  "superpowers@claude-plugins-official": true,
  "context7@claude-plugins-official": true
},
"extraKnownMarketplaces": {
  "engram": {
    "source": { "source": "github", "repo": "Gentleman-Programming/engram" }
  }
}
```

#### 7e. Status bar personalizado

```powershell
# Copiar el script del status bar
Copy-Item "$HOME\Documents\PowerShell\claude\statusline-command.sh" "$HOME\.claude\statusline-command.sh"
```

Luego agregar esto en `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

Muestra: `path | branch | model | ctx% | 5h% (reset) | 7d% (reset) | session | $cost`

#### 7f. MCPs

Already configured in `settings.json`. Set up your own tokens:

| MCP | What it is | Config |
|-----|-----------|--------|
| **engram** | Persistent memory | `engram.exe mcp --tools=agent` |
| **supabase** | DB via MCP | Replace `project_ref` with your own |

```json
"mcpServers": {
  "engram": {
    "command": "C:\\Users\\<you>\\bin\\engram.exe",
    "args": ["mcp", "--tools=agent"]
  },
  "supabase": {
    "type": "http",
    "url": "https://mcp.supabase.com/mcp?project_ref=YOUR_PROJECT_REF"
  }
}
```

---

### 8. OpenCode

#### 8a. Install OpenCode

```powershell
winget install OpenCode.OpenCode
# or via npm:
npm install -g opencode-ai
```

#### 8b. Copy config

```powershell
New-Item -ItemType Directory -Path "$HOME\.config\opencode" -Force | Out-Null
Copy-Item "$HOME\Documents\PowerShell\.config\opencode\opencode.json" "$HOME\.config\opencode\opencode.json"
Copy-Item "$HOME\Documents\PowerShell\.config\opencode\AGENTS.md" "$HOME\.config\opencode\AGENTS.md"
```

#### 8c. Agents included

| Agent | Mode | Description |
|-------|------|-------------|
| `gentleman` | primary | Senior Architect mentor — helpful first, challenging when needed |
| `sdd-orchestrator` | primary | Agent Teams Orchestrator — delegates all work to sub-agents |
| `english-teacher` | all | Personal English speaking coach with Engram memory |
| `sdd-apply/spec/design/tasks/verify/archive/explore/propose/init` | subagent | SDD pipeline sub-agents |

#### 8d. MCPs (OpenCode)

Already in `opencode.json`. Configure your own tokens:

| MCP | Type | Notes |
|-----|------|-------|
| **engram** | local | `engram mcp` — same binary as Claude Code |
| **context7** | remote | `https://mcp.context7.com/mcp` — no auth needed |
| **notion** | local | `npx @notionhq/notion-mcp-server` — set `NOTION_TOKEN` env var |
| **supabase** | remote | Replace `project_ref` with your own |

Set env vars:
```powershell
# Add to your profile or system env vars
$env:NOTION_TOKEN = "your_notion_integration_token"
```

---

### 9. Restore Engram memory (optional)

If you have a previous engram backup:

```powershell
engram-pull   # pulls from your git backup and reimports
```

If starting fresh, memory builds automatically as you work.

---

### 10. Verify everything works

```powershell
# Restart terminal, then:
cmds          # should show all profile commands
z             # zoxide initialized
lg            # lazygit opens
bat --version
eza --version
rg --version
fd --version
fzf --version
lazygit --version
```

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
| `engram-push` | Export + push AI memory to GitHub |
| `engram-pull` | Pull + import AI memory from GitHub |
| `cmds` | Show all profile commands |

### Zellij (inside Zellij only)

| Keybinding | What it does |
|------------|-------------|
| `Alt+F` | Toggle / create floating pane at current dir |
| `Alt+F, f` | Force create new floating pane |

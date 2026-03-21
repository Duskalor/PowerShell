# PowerShell Profile

My PowerShell 7 profile for Windows + Alacritty + Zellij.

## Features

- **Terminal-Icons** — File icons in `ls` output
- **PSReadLine ListView** — Autocomplete predictions
- **Zellij CWD inheritance** — New panes open in current directory (workaround for Windows port)
- **Engram sync** — Push/pull persistent AI memory to GitHub

## Quick Navigation

| Command | Path |
|---------|------|
| `d` | `~/Documents/Proyects` |
| `pr` | `~/Documents/Proyects/React` |
| `n` | `~/Documents/Proyects/Node` |
| `ne` | `~/Documents/Proyects/Nextjs` |
| `nes` | `~/Documents/Proyects/nestjs` |
| `as` | `~/Documents/Proyects/astro` |
| `js` | `~/Documents/Proyects/javascript` |
| `l` | `~/Documents/Proyects/Laravel` |
| `p` | `~/Documents/Proyects/PHP` |
| `mono` | `~/Documents/Proyects/MonoRepo` |

## Project Scaffolding

| Command | What it does |
|---------|-------------|
| `vite <name>` | Create Vite project + install + open VSCode + dev |
| `vitet <name>` | Same + Tailwind |
| `next <name>` | Create Next.js project + open VSCode + dev |
| `astro <name>` | Create Astro project + open VSCode + dev |

## Utilities

| Command | What it does |
|---------|-------------|
| `dev` | `pnpm run dev` |
| `w` | Open current folder in explorer |
| `cf <path> <files>` | Create folder + files (.ts default) |
| `newdb [port]` | Spin up Postgres via Docker + copy connection string |
| `rmj [name]` | Parse judicial HTML into searchable TXT + HTML |
| `engram-push` | Export + push engram memories to GitHub |
| `engram-pull` | Pull + import engram memories from GitHub |

## Setup

```powershell
# Clone to PowerShell profile directory
git clone https://github.com/Duskalor/PowerShell.git ~/Documents/PowerShell

# Required modules
Install-Module Terminal-Icons -Scope CurrentUser
Install-Module PSReadLine -Scope CurrentUser
```

<#
    Dotfiles manifest — the single source of truth for what gets linked where.

    Both bootstrap.ps1 and sync.ps1 read this file. Adding a new config to the
    repo means adding one row here; nothing else changes.

    Repo   : path relative to the repository root.
    Target : destination on the machine. Tokens {HOME} and {APPDATA} are
             expanded at runtime so the manifest stays machine independent.
    Type    : File or Directory. Determines the kind of symbolic link created.

    Never link a whole directory that also holds caches or downloaded
    artifacts. ~/.claude carries ~350 MB of session history and plugins,
    ~/.config/opencode carries node_modules, and ~/.config/zellij carries
    downloaded .wasm plugins. Those directories are linked entry by entry.
#>
@{
    Links = @(
        # --- Home dotfiles ---
        @{ Repo = 'home/.gitconfig';                    Target = '{HOME}/.gitconfig';                         Type = 'File' }
        @{ Repo = 'home/.wezterm.lua';                  Target = '{HOME}/.wezterm.lua';                       Type = 'File' }

        # --- Alacritty ---
        @{ Repo = 'config/alacritty/alacritty.toml';    Target = '{APPDATA}/alacritty/alacritty.toml';        Type = 'File' }
        @{ Repo = 'config/alacritty/alacritty-wsl.toml';Target = '{APPDATA}/alacritty/alacritty-wsl.toml';    Type = 'File' }

        # --- Zellij (plugins/ stays local: downloaded .wasm binaries) ---
        @{ Repo = 'config/zellij/config.kdl';           Target = '{HOME}/.config/zellij/config.kdl';          Type = 'File' }
        @{ Repo = 'config/zellij/layouts';              Target = '{HOME}/.config/zellij/layouts';             Type = 'Directory' }

        # --- Git ---
        @{ Repo = 'config/git/ignore';                  Target = '{HOME}/.config/git/ignore';                 Type = 'File' }

        # --- Claude Code (allowlist: settings.local.json is never linked) ---
        @{ Repo = 'config/claude/settings.json';        Target = '{HOME}/.claude/settings.json';              Type = 'File' }
        @{ Repo = 'config/claude/CLAUDE.md';            Target = '{HOME}/.claude/CLAUDE.md';                  Type = 'File' }
        @{ Repo = 'config/claude/statusline-command.sh';Target = '{HOME}/.claude/statusline-command.sh';      Type = 'File' }
        @{ Repo = 'config/claude/agents';               Target = '{HOME}/.claude/agents';                     Type = 'Directory' }
        @{ Repo = 'config/claude/commands';             Target = '{HOME}/.claude/commands';                   Type = 'Directory' }
        @{ Repo = 'config/claude/output-styles';        Target = '{HOME}/.claude/output-styles';              Type = 'Directory' }
        @{ Repo = 'config/claude/skills';               Target = '{HOME}/.claude/skills';                     Type = 'Directory' }

        # --- Shared agent skills (the real source behind crush/goose symlinks) ---
        @{ Repo = 'config/agents/skills';               Target = '{HOME}/.agents/skills';                     Type = 'Directory' }

        # --- OpenCode (entry by entry: node_modules stays local) ---
        @{ Repo = 'config/opencode/opencode.json';      Target = '{HOME}/.config/opencode/opencode.json';     Type = 'File' }
        @{ Repo = 'config/opencode/AGENTS.md';          Target = '{HOME}/.config/opencode/AGENTS.md';         Type = 'File' }
        @{ Repo = 'config/opencode/tui.json';           Target = '{HOME}/.config/opencode/tui.json';          Type = 'File' }
        @{ Repo = 'config/opencode/package.json';       Target = '{HOME}/.config/opencode/package.json';      Type = 'File' }
        @{ Repo = 'config/opencode/agents';             Target = '{HOME}/.config/opencode/agents';            Type = 'Directory' }
        @{ Repo = 'config/opencode/commands';           Target = '{HOME}/.config/opencode/commands';          Type = 'Directory' }
        @{ Repo = 'config/opencode/plugin';             Target = '{HOME}/.config/opencode/plugin';            Type = 'Directory' }
        @{ Repo = 'config/opencode/plugins';            Target = '{HOME}/.config/opencode/plugins';           Type = 'Directory' }
        @{ Repo = 'config/opencode/profiles';           Target = '{HOME}/.config/opencode/profiles';          Type = 'Directory' }
        @{ Repo = 'config/opencode/prompts';            Target = '{HOME}/.config/opencode/prompts';           Type = 'Directory' }
        @{ Repo = 'config/opencode/skills';             Target = '{HOME}/.config/opencode/skills';            Type = 'Directory' }

        # --- Gentleman Guardian Angel ---
        @{ Repo = 'config/gga/AGENTS.md';               Target = '{HOME}/.config/gga/AGENTS.md';              Type = 'File' }
        @{ Repo = 'config/gga/config';                  Target = '{HOME}/.config/gga/config';                 Type = 'File' }
    )

    # Files the bootstrap creates from a template when they do not exist.
    # These hold machine specific values and are never committed.
    Templates = @(
        @{ Example = 'config/claude/settings.local.json.example'; Target = '{HOME}/.claude/settings.local.json' }
    )
}

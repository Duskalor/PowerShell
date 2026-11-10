-- DuskaDev "Brasa": embers at dusk.
--
-- Built on tokyonight (LazyVim's default) by swapping its palette, so every
-- plugin LazyVim ships keeps proper highlights without a hand-written theme.
-- Same colors as Alacritty, WezTerm, Windows Terminal and the Zellij theme.

local brasa = {
  bg = "#19120f",
  bg_dark = "#140e0c",
  panel = "#2a1f19",
  sel = "#3a2b22",
  fg = "#f0e3d6",
  fg_dim = "#c9b8a8",
  muted = "#97806f",
  dim = "#64534a",
  comment = "#7d6a5d",
  orange = "#ff8a3d",
  peach = "#ffb070",
  red = "#e5534b",
  gold = "#f2c14e",
  rose = "#d9849a",
  green = "#a7c080",
  blue = "#8fb3c9",
  cyan = "#8ec5b8",
}

-- "DUSKADEV" in ANSI Shadow, assembled letter by letter so the rows always line up.
local letters = {
  D = { "██████╗ ", "██╔══██╗", "██║  ██║", "██║  ██║", "██████╔╝", "╚═════╝ " },
  U = { "██╗   ██╗", "██║   ██║", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
  S = { "███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝" },
  K = { "██╗  ██╗", "██║ ██╔╝", "█████╔╝ ", "██╔═██╗ ", "██║  ██╗", "╚═╝  ╚═╝" },
  A = { " █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
  E = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝" },
  V = { "██╗   ██╗", "██║   ██║", "██║   ██║", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚═══╝  " },
}

local function banner(word)
  local rows = {}
  for r = 1, 6 do
    local line = {}
    for ch in word:gmatch(".") do
      table.insert(line, letters[ch][r])
    end
    rows[r] = table.concat(line, " ")
  end
  return table.concat(rows, "\n") .. "\n\n▲  built at dusk  ·  Paul Cruz"
end

return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
      on_colors = function(c)
        c.bg = brasa.bg
        c.bg_dark = brasa.bg_dark
        c.bg_dark1 = brasa.bg_dark
        c.bg_float = brasa.bg_dark
        c.bg_sidebar = brasa.bg_dark
        c.bg_statusline = brasa.panel
        c.bg_popup = brasa.bg_dark
        c.bg_highlight = brasa.panel
        c.bg_visual = brasa.sel
        c.bg_search = brasa.sel
        c.border = brasa.sel
        c.border_highlight = brasa.orange
        c.fg = brasa.fg
        c.fg_dark = brasa.fg_dim
        c.fg_float = brasa.fg
        c.fg_sidebar = brasa.fg_dim
        c.fg_gutter = brasa.dim
        c.comment = brasa.comment
        c.dark3 = brasa.dim
        c.dark5 = brasa.muted
        c.terminal_black = brasa.dim
        -- syntax: keywords orange, functions gold, strings green, types rose
        c.purple = brasa.orange
        c.magenta = brasa.orange
        c.magenta2 = brasa.red
        c.blue = brasa.gold
        c.blue0 = brasa.sel
        c.blue1 = brasa.rose
        c.blue2 = brasa.cyan
        c.blue5 = brasa.blue
        c.blue6 = brasa.cyan
        c.blue7 = brasa.sel
        c.cyan = brasa.blue
        c.teal = brasa.cyan
        c.green = brasa.green
        c.green1 = brasa.cyan
        c.green2 = brasa.cyan
        c.orange = brasa.peach
        c.yellow = brasa.gold
        c.red = brasa.red
        c.red1 = brasa.red
        c.git = { add = brasa.green, change = brasa.gold, delete = brasa.red, ignore = brasa.dim }
      end,
      on_highlights = function(hl, c)
        hl.CursorLineNr = { fg = brasa.orange, bold = true }
        hl.LineNr = { fg = brasa.dim }
        hl.SnacksDashboardHeader = { fg = brasa.orange }
        hl.SnacksDashboardIcon = { fg = brasa.gold }
        hl.SnacksDashboardKey = { fg = brasa.orange, bold = true }
        hl.SnacksDashboardDesc = { fg = brasa.fg_dim }
        hl.SnacksDashboardFooter = { fg = brasa.muted, italic = true }
        hl.WinSeparator = { fg = brasa.sel }
        hl.FloatBorder = { fg = brasa.sel, bg = c.bg_float }
      end,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "tokyonight-night" },
  },

  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = { header = banner("DUSKADEV") },
      },
    },
  },
}

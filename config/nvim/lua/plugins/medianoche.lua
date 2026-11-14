-- DuskaDev "Medianoche": night blue with a single amber accent.
--
-- Built on tokyonight (LazyVim's default) by swapping its palette, so every
-- plugin LazyVim ships keeps proper highlights without a hand-written theme.
-- Same colors as Alacritty, WezTerm, Windows Terminal and the Zellij theme.

local p = {
  bg = "#0d1320",
  bg_dark = "#0a0f1a",
  panel = "#172033",
  sel = "#26334d",
  fg = "#d8e0ee",
  fg_dim = "#aab6ca",
  muted = "#6a7a96",
  dim = "#46536b",
  comment = "#5d6d88",
  amber = "#f2b84b",
  peach = "#ffd08a",
  red = "#ef6b73",
  pink = "#e88fb5",
  green = "#8fd18f",
  blue = "#5aa9ff",
  teal = "#4fd1c5",
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
  return table.concat(rows, "\n") .. "\n\n☾  code after sunset  ·  Paul Cruz"
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
        c.bg = p.bg
        c.bg_dark = p.bg_dark
        c.bg_dark1 = p.bg_dark
        c.bg_float = p.bg_dark
        c.bg_sidebar = p.bg_dark
        c.bg_statusline = p.panel
        c.bg_popup = p.bg_dark
        c.bg_highlight = p.panel
        c.bg_visual = p.sel
        c.bg_search = p.sel
        c.border = p.sel
        c.border_highlight = p.amber
        c.fg = p.fg
        c.fg_dark = p.fg_dim
        c.fg_float = p.fg
        c.fg_sidebar = p.fg_dim
        c.fg_gutter = p.dim
        c.comment = p.comment
        c.dark3 = p.dim
        c.dark5 = p.muted
        c.terminal_black = p.dim
        -- syntax: keywords amber, functions blue, strings green, types teal
        c.purple = p.amber
        c.magenta = p.amber
        c.magenta2 = p.red
        c.blue = p.blue
        c.blue0 = p.sel
        c.blue1 = p.teal
        c.blue2 = p.teal
        c.blue5 = p.blue
        c.blue6 = p.teal
        c.blue7 = p.sel
        c.cyan = p.blue
        c.teal = p.teal
        c.green = p.green
        c.green1 = p.teal
        c.green2 = p.teal
        c.orange = p.peach
        c.yellow = p.amber
        c.red = p.red
        c.red1 = p.red
        c.git = { add = p.green, change = p.amber, delete = p.red, ignore = p.dim }
      end,
      on_highlights = function(hl, c)
        hl.CursorLineNr = { fg = p.amber, bold = true }
        hl.LineNr = { fg = p.dim }
        hl.SnacksDashboardHeader = { fg = p.amber }
        hl.SnacksDashboardIcon = { fg = p.blue }
        hl.SnacksDashboardKey = { fg = p.amber, bold = true }
        hl.SnacksDashboardDesc = { fg = p.fg_dim }
        hl.SnacksDashboardFooter = { fg = p.muted, italic = true }
        hl.WinSeparator = { fg = p.sel }
        hl.FloatBorder = { fg = p.sel, bg = c.bg_float }
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

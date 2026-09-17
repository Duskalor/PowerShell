local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ─── Shell ───────────────────────────────────────────────────────────────────
config.default_prog = { "zellij.exe" }

-- ─── Font ────────────────────────────────────────────────────────────────────
config.font = wezterm.font("IosevkaTerm NF")
config.font_size = 16.0

-- ─── Window ──────────────────────────────────────────────────────────────────
config.window_background_opacity = 0.90
config.window_decorations = "TITLE | RESIZE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

-- ─── Performance ─────────────────────────────────────────────────────────────
config.max_fps = 240
config.front_end = "OpenGL"

local gpus = wezterm.gui.enumerate_gpus()
if #gpus > 0 then
  config.webgpu_preferred_adapter = gpus[1]
end

-- ─── Cursor ──────────────────────────────────────────────────────────────────
config.default_cursor_style = "SteadyBlock"
config.cursor_blink_rate = 0

-- ─── Environment ─────────────────────────────────────────────────────────────
config.set_environment_variables = {
  TERM = "xterm-256color",
  COLORTERM = "truecolor",
}

-- ─── Colors ──────────────────────────────────────────────────────────────────
config.colors = {
  foreground = "#C9C7CD",
  background = "#000000",

  cursor_bg = "#92A2D5",
  cursor_fg = "#C9C7CD",
  cursor_border = "#92A2D5",

  selection_fg = "#C9C7CD",
  selection_bg = "#3B4252",

  scrollbar_thumb = "#4C566A",
  split = "#4C566A",

  ansi = {
    "#000000", -- black
    "#EA83A5", -- red
    "#90B99F", -- green
    "#E6B99D", -- yellow
    "#85B5BA", -- blue
    "#92A2D5", -- magenta
    "#85B5BA", -- cyan
    "#C9C7CD", -- white
  },

  brights = {
    "#4C566A", -- bright black
    "#EA83A5", -- bright red
    "#90B99F", -- bright green
    "#E6B99D", -- bright yellow
    "#85B5BA", -- bright blue
    "#92A2D5", -- bright magenta
    "#85B5BA", -- bright cyan
    "#C9C7CD", -- bright white
  },

  indexed = {
    [16] = "#F5A191",
    [17] = "#E29ECA",
  },
}

-- ─── Tab bar ─────────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = true
config.enable_scroll_bar = false

-- ─── Kitty graphics (imagen paste en Claude Code) ────────────────────────────
config.enable_kitty_graphics = true

-- ─── Keybindings ─────────────────────────────────────────────────────────────
config.keys = {
  {
    key = "c",
    mods = "CTRL",
    action = wezterm.action_callback(function(window, pane)
      local has_selection = window:get_selection_text_for_pane(pane) ~= ""
      if has_selection then
        window:perform_action(wezterm.action.CopyTo("Clipboard"), pane)
      else
        window:perform_action(wezterm.action.SendKey({ key = "c", mods = "CTRL" }), pane)
      end
    end),
  },
  {
    key = "v",
    mods = "CTRL",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
  -- Alt+V: paste imágenes en Claude Code (Windows bug workaround)
  {
    key = "v",
    mods = "ALT",
    action = wezterm.action.SendKey({ key = "v", mods = "ALT" }),
  },
}

return config

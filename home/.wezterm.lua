local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ─── Shell ───────────────────────────────────────────────────────────────────
config.default_prog = { "zellij.exe" }

-- ─── Font ────────────────────────────────────────────────────────────────────
-- CaskaydiaCove NF: Cascadia Code with Nerd Font icons. calt/liga turn the
-- ligatures on (=> !== >= ??); ss01 is Cascadia's cursive italic.
config.font = wezterm.font_with_fallback({ "CaskaydiaCove NF", "IosevkaTerm NF" })
config.font_size = 15.0
config.harfbuzz_features = { "calt=1", "liga=1", "ss01=1" }

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
-- DuskaDev "Brasa": same palette as Alacritty, Zellij and LazyVim.
config.colors = {
  foreground = "#f0e3d6",
  background = "#19120f",

  cursor_bg = "#ff8a3d",
  cursor_fg = "#19120f",
  cursor_border = "#ff8a3d",

  selection_fg = "#f0e3d6",
  selection_bg = "#3a2b22",

  scrollbar_thumb = "#3a2b22",
  split = "#3a2b22",

  ansi = {
    "#2a1f19", -- black
    "#e5534b", -- red
    "#a7c080", -- green
    "#f2c14e", -- yellow
    "#8fb3c9", -- blue
    "#d9849a", -- magenta
    "#8ec5b8", -- cyan
    "#d8c8b8", -- white
  },

  brights = {
    "#64534a", -- bright black
    "#ff6b5e", -- bright red
    "#bcd197", -- bright green
    "#ffd36b", -- bright yellow
    "#a5c6db", -- bright blue
    "#e8a0b2", -- bright magenta
    "#a6d8cb", -- bright cyan
    "#f0e3d6", -- bright white
  },

  indexed = {
    [16] = "#ff8a3d",
    [17] = "#ffb070",
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

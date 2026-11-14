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
-- DuskaDev "Medianoche": same palette as Alacritty, Zellij and LazyVim.
config.colors = {
  foreground = "#d8e0ee",
  background = "#0d1320",

  cursor_bg = "#f2b84b",
  cursor_fg = "#0d1320",
  cursor_border = "#f2b84b",

  selection_fg = "#d8e0ee",
  selection_bg = "#26334d",

  scrollbar_thumb = "#26334d",
  split = "#26334d",

  ansi = {
    "#172033", -- black
    "#ef6b73", -- red
    "#8fd18f", -- green
    "#f2b84b", -- yellow
    "#5aa9ff", -- blue
    "#e88fb5", -- magenta
    "#4fd1c5", -- cyan
    "#b8c3d6", -- white
  },

  brights = {
    "#46536b", -- bright black
    "#ff8a91", -- bright red
    "#a8e0a8", -- bright green
    "#ffcc6b", -- bright yellow
    "#7dbcff", -- bright blue
    "#f2a8c8", -- bright magenta
    "#6fe0d5", -- bright cyan
    "#d8e0ee", -- bright white
  },

  indexed = {
    [16] = "#f2b84b",
    [17] = "#ffd08a",
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

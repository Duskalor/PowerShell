#!/usr/bin/env bash
input=$(cat)

# --- Detect JS interpreter (node) ---
NODE_EXE=""
if command -v node >/dev/null 2>&1; then
  NODE_EXE="node"
elif command -v nodejs >/dev/null 2>&1; then
  NODE_EXE="nodejs"
fi

# --- Single node call: parse the JSON once, emit every field as a line ---
fields=""
if [ -n "$NODE_EXE" ]; then
  fields=$(printf '%s' "$input" | "$NODE_EXE" -e '
const fs = require("fs");
const os = require("os");
const path = require("path");

let d = {};
try { d = JSON.parse(fs.readFileSync(0, "utf8")); } catch (e) { d = {}; }

function usedPct(ctx) {
  if (!ctx || typeof ctx !== "object") return "";
  let v = ctx.used_percentage;
  if (v == null) {
    const tin = ctx.total_input_tokens || 0;
    const tout = ctx.total_output_tokens || 0;
    const size = ctx.context_window_size || 0;
    if (size > 0) v = (tin + tout) / size * 100;
  }
  return v == null ? "" : String(v);
}

function pctFrom(obj) {
  if (!obj || typeof obj !== "object") return "";
  for (const k of ["percentage", "used_percentage", "percent_used", "percentUsed"]) {
    if (obj[k] != null) return String(Number(obj[k]));
  }
  const usedKeys = ["tokens_used", "inputTokens", "input_tokens", "used"];
  const limKeys = ["tokens_limit", "tokens_max", "limit", "max"];
  for (const uk of usedKeys) {
    for (const lk of limKeys) {
      const u = obj[uk], m = obj[lk];
      if (u != null && m && Number(m) > 0) return String((Number(u) / Number(m)) * 100);
    }
  }
  return "";
}

function fmtReset(obj) {
  if (!obj || typeof obj !== "object") return "";
  const v = obj.resets_at != null ? obj.resets_at : obj.reset_at;
  if (v == null) return "";
  let dt;
  if (typeof v === "number") dt = new Date(v * 1000);
  else {
    dt = new Date(String(v));
    if (isNaN(dt.getTime())) return "";
  }
  const secs = Math.floor((dt.getTime() - Date.now()) / 1000);
  if (secs <= 0) return "now";
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  return h > 0 ? h + "h" + String(m).padStart(2, "0") + "m" : m + "m";
}

function displayCwd(p) {
  p = (p || "").trim();
  let parts = p.split(/[\\/]/).filter(Boolean);
  const low = parts.map((x) => x.toLowerCase());
  if (low.length >= 3 && (low[0] === "c:" || low[0] === "d:") && low[1] === "users") {
    parts = ["~"].concat(parts.slice(3));
  } else if (low.length >= 2 && low[0] === "users") {
    parts = ["~"].concat(parts.slice(2));
  }
  const sep = p.indexOf("\\") !== -1 ? "\\" : "/";
  if (parts.length > 2) {
    return "..." + sep + parts.slice(-2).join(sep);
  }
  return parts.join(sep);
}

const cwd = (d.workspace && d.workspace.current_dir) || d.cwd || "";
const model = (d.model && d.model.display_name) || "";
const used = usedPct(d.context_window);
const session_name = d.session_name || "";
const cost = d.cost || {};
const cost_usd = cost.total_cost_usd != null ? String(cost.total_cost_usd) : "";

const rl = d.rate_limits || {};
const fiveHour = typeof rl.five_hour === "object" && rl.five_hour ? rl.five_hour : {};
const sevenDay = typeof rl.seven_day === "object" && rl.seven_day ? rl.seven_day : {};

if (rl.five_hour || rl.seven_day) {
  try {
    const p = path.join(os.homedir(), ".claude", "statusline-rl-debug.json");
    fs.writeFileSync(p, JSON.stringify(rl, null, 2));
  } catch (e) {}
}

const five_h_pct = pctFrom(fiveHour);
const seven_d_pct = pctFrom(sevenDay);
const five_h_reset = fmtReset(fiveHour);
const seven_d_reset = fmtReset(sevenDay);
const display_cwd = displayCwd(cwd);

console.log([cwd, model, used, session_name, cost_usd, five_h_pct, seven_d_pct, five_h_reset, seven_d_reset, display_cwd].join("\n"));
')
fi

mapfile -t _f <<< "$fields"
cwd="${_f[0]}"
model="${_f[1]}"
used="${_f[2]}"
session_name="${_f[3]}"
cost_usd="${_f[4]}"
five_h_pct="${_f[5]}"
seven_d_pct="${_f[6]}"
five_h_reset="${_f[7]}"
seven_d_reset="${_f[8]}"
display_cwd="${_f[9]}"

# --- Git branch + dirty state ---
branch=""
git_staged=0
git_modified=0
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  # Parse porcelain: X = index (staged), Y = worktree (unstaged). "??" = untracked.
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    _x=${_line:0:1}
    _y=${_line:1:1}
    case "$_x" in [MADRC]) git_staged=$((git_staged + 1)) ;; esac
    if [ "$_x$_y" = "??" ]; then
      git_modified=$((git_modified + 1))
    else
      case "$_y" in [MD]) git_modified=$((git_modified + 1)) ;; esac
    fi
  done < <(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
fi

# --- Colors ---
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
BLUE=$'\033[34m'
RED=$'\033[31m'
WHITE=$'\033[37m'
CYAN=$'\033[36m'

pct_color() {
  local int
  int=$(printf "%.0f" "$1" 2>/dev/null) || int=0
  if   [ "$int" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$int" -ge 50 ]; then printf '%s' "$YELLOW"
  else                         printf '%s' "$GREEN"
  fi
}

# Repeat a character N times (safe when N=0 → prints nothing).
repeat_char() {
  local ch="$1" n="$2" out="" i=0
  while [ "$i" -lt "$n" ]; do out="$out$ch"; i=$((i + 1)); done
  printf '%s' "$out"
}

# Render a progress bar for a percentage: filled cells colored, rest dimmed.
# Usage: make_bar <percentage> <width>
make_bar() {
  local pct="$1" width="$2" int filled empty col
  int=$(printf "%.0f" "$pct" 2>/dev/null) || int=0
  col=$(pct_color "$int")
  filled=$(( (int * width + 50) / 100 ))
  [ "$filled" -lt 0 ] && filled=0
  [ "$filled" -gt "$width" ] && filled=$width
  empty=$(( width - filled ))
  printf "${col}%s${DIM}%s${RESET}" \
    "$(repeat_char "█" "$filled")" "$(repeat_char "░" "$empty")"
}

# --- Segments ---

# 1. CWD
seg_cwd=$(printf "${BOLD}${BLUE}%s${RESET}" "$display_cwd")

# 2. Git branch + dirty markers (✚ staged / ● modified, shown only when > 0)
if [ -n "$branch" ]; then
  seg_git=$(printf "${GREEN} %s${RESET}" "$branch")
  [ "$git_staged" -gt 0 ]   && seg_git="$seg_git$(printf " ${GREEN}✚%s${RESET}" "$git_staged")"
  [ "$git_modified" -gt 0 ] && seg_git="$seg_git$(printf " ${YELLOW}●%s${RESET}" "$git_modified")"
else
  seg_git=""
fi

# 3. Model
if [ -n "$model" ]; then
  seg_model=$(printf "${MAGENTA}%s${RESET}" "$model")
else
  seg_model=""
fi

# 4. Context window (percentage)
# Bar width shared by the rate-limit segments below.
RL_BAR_WIDTH=6
if [ -n "$used" ] && [ "$used" != "None" ]; then
  col=$(pct_color "$used")
  used_int=$(printf "%.0f" "$used")
  seg_ctx=$(printf "${DIM}ctx${RESET} ${col}%s%%${RESET}" "$used_int")
else
  seg_ctx=$(printf "${DIM}ctx --${RESET}")
fi

# 5. Session cost
if [ -n "$cost_usd" ] && [ "$cost_usd" != "None" ]; then
  cost_fmt=$(printf "%.3f" "$cost_usd" 2>/dev/null || echo "$cost_usd")
  seg_cost=$(printf "${CYAN}\$%s${RESET}" "$cost_fmt")
else
  seg_cost=""
fi

# 6. 5-hour rate limit
seg_5h=""
if [ -n "$five_h_pct" ] && [ "$five_h_pct" != "None" ]; then
  col=$(pct_color "$five_h_pct")
  fh_int=$(printf "%.0f" "$five_h_pct")
  fh_bar=$(make_bar "$five_h_pct" "$RL_BAR_WIDTH")
  if [ -n "$five_h_reset" ] && [ "$five_h_reset" != "None" ]; then
    seg_5h=$(printf "${DIM}5h${RESET} %s ${col}%s%%${RESET} ${DIM}(%s)${RESET}" "$fh_bar" "$fh_int" "$five_h_reset")
  else
    seg_5h=$(printf "${DIM}5h${RESET} %s ${col}%s%%${RESET}" "$fh_bar" "$fh_int")
  fi
fi

# 7. 7-day rate limit
seg_7d=""
if [ -n "$seven_d_pct" ] && [ "$seven_d_pct" != "None" ]; then
  col=$(pct_color "$seven_d_pct")
  sd_int=$(printf "%.0f" "$seven_d_pct")
  sd_bar=$(make_bar "$seven_d_pct" "$RL_BAR_WIDTH")
  if [ -n "$seven_d_reset" ] && [ "$seven_d_reset" != "None" ]; then
    seg_7d=$(printf "${DIM}7d${RESET} %s ${col}%s%%${RESET} ${DIM}(%s)${RESET}" "$sd_bar" "$sd_int" "$seven_d_reset")
  else
    seg_7d=$(printf "${DIM}7d${RESET} %s ${col}%s%%${RESET}" "$sd_bar" "$sd_int")
  fi
fi

# 8. Session name
if [ -n "$session_name" ]; then
  seg_session=$(printf "${DIM}${WHITE}\"%s\"${RESET}" "$session_name")
else
  seg_session=""
fi

# --- Assemble (adaptive: wraps onto extra lines when the terminal is narrow) ---
# Claude Code captures stdout, so tput/COLUMNS-from-tty do not work. It instead
# exports COLUMNS with the real terminal width (v2.1.153+). If unset, we fall
# back to a single line (no wrapping) — same as the old behavior.
avail=0
if [ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 2 ] 2>/dev/null; then
  avail=$(( COLUMNS - 1 ))
fi

segs=()
[ -n "$seg_cwd" ]     && segs+=("$seg_cwd")
[ -n "$seg_git" ]     && segs+=("$seg_git")
[ -n "$seg_model" ]   && segs+=("$seg_model")
[ -n "$seg_ctx" ]     && segs+=("$seg_ctx")
[ -n "$seg_5h" ]      && segs+=("$seg_5h")
[ -n "$seg_7d" ]      && segs+=("$seg_7d")
[ -n "$seg_session" ] && segs+=("$seg_session")
[ -n "$seg_cost" ]    && segs+=("$seg_cost")

if [ -n "$NODE_EXE" ] && [ "${#segs[@]}" -gt 0 ]; then
  # Greedy line-wrap by VISIBLE width (ANSI color codes are stripped when
  # measuring). Segments are fed NUL-separated so their contents stay intact.
  printf '%s\0' "${segs[@]}" | "$NODE_EXE" -e '
const fs = require("fs");

let cols = parseInt(process.argv[1], 10);
if (!Number.isFinite(cols) || cols <= 0) cols = Infinity;

const data = fs.readFileSync(0, "utf8");
const segs = data.split("\0").filter((s) => s !== "");

const DIM = "[2m";
const RESET = "[0m";
const sep = DIM + " | " + RESET;
const sepW = " | ".length;
const ansi = /\[[0-9;]*m/g;
const vw = (s) => s.replace(ansi, "").length;

const lines = [];
let cur = "";
let curW = 0;
for (const s of segs) {
  const w = vw(s);
  if (!cur) {
    cur = s;
    curW = w;
  } else if (curW + sepW + w <= cols) {
    cur += sep + s;
    curW += sepW + w;
  } else {
    lines.push(cur);
    cur = s;
    curW = w;
  }
}
if (cur) lines.push(cur);

process.stdout.write(lines.join("\n") + "\n");
' "$avail"
else
  # Fallback (no node): single line.
  SEP=$(printf "${DIM} | ${RESET}")
  line=""
  for s in "${segs[@]}"; do
    if [ -z "$line" ]; then line="$s"; else line="$line${SEP}$s"; fi
  done
  printf '%s\n' "$line"
fi

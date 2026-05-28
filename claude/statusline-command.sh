#!/usr/bin/env bash
input=$(cat)

# Detect python interpreter
PYTHON_EXE=""
PYTHON_PRE=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_EXE="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_EXE="python"
elif command -v py >/dev/null 2>&1; then
  PYTHON_EXE="py"
  PYTHON_PRE="-3"
elif [ -x "/c/Users/Paul Cruz/AppData/Local/Programs/Python/Python311/python.exe" ]; then
  PYTHON_EXE="/c/Users/Paul Cruz/AppData/Local/Programs/Python/Python311/python.exe"
fi

run_py() {
  if [ -z "$PYTHON_EXE" ]; then
    cat >/dev/null
    return 1
  fi
  if [ -n "$PYTHON_PRE" ]; then
    "$PYTHON_EXE" "$PYTHON_PRE" "$@"
  else
    "$PYTHON_EXE" "$@"
  fi
}

# --- Extract fields (separate calls — avoids quoting/eval bugs) ---

cwd=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('workspace', {}).get('current_dir') or d.get('cwd', ''))
")

model=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('model', {}).get('display_name', ''))
")

used=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
ctx = d.get('context_window', {}) or {}
v = ctx.get('used_percentage')
if v is None:
    tin  = ctx.get('total_input_tokens') or 0
    tout = ctx.get('total_output_tokens') or 0
    size = ctx.get('context_window_size') or 0
    if size > 0:
        v = (tin + tout) / size * 100
print('' if v is None else v)
")

session_name=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_name', '') or '')
")

cost_usd=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
cost = d.get('cost', {}) or {}
v = cost.get('total_cost_usd')
print('' if v is None else v)
")

five_h_pct=$(echo "$input" | run_py -c "
import sys, json
d = json.load(sys.stdin)
rl  = d.get('rate_limits', {}) or {}
obj = rl.get('five_hour') or {}
if not isinstance(obj, dict): obj = {}
for key in ('percentage','used_percentage','percent_used','percentUsed'):
    v = obj.get(key)
    if v is not None: print(float(v)); exit()
for uk in ('tokens_used','inputTokens','input_tokens','used'):
    for lk in ('tokens_limit','tokens_max','limit','max'):
        u, m = obj.get(uk), obj.get(lk)
        if u is not None and m and float(m) > 0:
            print(float(u)/float(m)*100); exit()
print('')
")

seven_d_pct=$(echo "$input" | run_py -c "
import sys, json, os
d = json.load(sys.stdin)
rl  = d.get('rate_limits', {}) or {}
obj = rl.get('seven_day') or {}
if not isinstance(obj, dict): obj = {}
# debug: dump full rate_limits when any field has data
if rl.get('five_hour') or rl.get('seven_day'):
    _p = os.path.join(os.path.expanduser('~'), '.claude', 'statusline-rl-debug.json')
    with open(_p, 'w') as _f:
        json.dump(rl, _f, indent=2)
for key in ('percentage','used_percentage','percent_used','percentUsed'):
    v = obj.get(key)
    if v is not None: print(float(v)); exit()
for uk in ('tokens_used','inputTokens','input_tokens','used'):
    for lk in ('tokens_limit','tokens_max','limit','max'):
        u, m = obj.get(uk), obj.get(lk)
        if u is not None and m and float(m) > 0:
            print(float(u)/float(m)*100); exit()
print('')
")

five_h_reset=$(echo "$input" | run_py -c "
import sys, json
from datetime import datetime, timezone
d = json.load(sys.stdin)
rl  = d.get('rate_limits', {}) or {}
obj = rl.get('five_hour') or {}
if not isinstance(obj, dict): obj = {}
v = obj.get('resets_at') or obj.get('reset_at')
if v:
    try:
        dt   = datetime.fromtimestamp(float(v), tz=timezone.utc) if isinstance(v, (int,float)) else datetime.fromisoformat(str(v).replace('Z','+00:00'))
        secs = int((dt - datetime.now(timezone.utc)).total_seconds())
        if secs <= 0: print('now')
        else:
            h = secs // 3600; m = (secs % 3600) // 60
            print(f'{h}h{m:02d}m' if h > 0 else f'{m}m')
    except: print('')
else: print('')
")

seven_d_reset=$(echo "$input" | run_py -c "
import sys, json
from datetime import datetime, timezone
d = json.load(sys.stdin)
rl  = d.get('rate_limits', {}) or {}
obj = rl.get('seven_day') or {}
if not isinstance(obj, dict): obj = {}
v = obj.get('resets_at') or obj.get('reset_at')
if v:
    try:
        dt   = datetime.fromtimestamp(float(v), tz=timezone.utc) if isinstance(v, (int,float)) else datetime.fromisoformat(str(v).replace('Z','+00:00'))
        secs = int((dt - datetime.now(timezone.utc)).total_seconds())
        if secs <= 0: print('now')
        else:
            h = secs // 3600; m = (secs % 3600) // 60
            print(f'{h}h{m:02d}m' if h > 0 else f'{m}m')
    except: print('')
else: print('')
")

# --- Git branch ---
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
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

# --- Segments ---

# 1. CWD
display_cwd=$(echo "$cwd" | run_py -c "
import sys, re
p = sys.stdin.read().strip()
parts = [x for x in re.split(r'[\\\\/]', p) if x]
low = [x.lower() for x in parts]
if len(low) >= 3 and low[0] in ('c:','d:') and low[1] == 'users':
    parts = ['~'] + parts[3:]
elif len(low) >= 2 and low[0] == 'users':
    parts = ['~'] + parts[2:]
if len(parts) > 2:
    tail = parts[-2:]
    sep = '\\\\\\\\' if '\\\\\\\\' in p else '/'
    print('...' + sep + sep.join(tail))
else:
    sep = '\\\\\\\\' if '\\\\\\\\' in p else '/'
    print(sep.join(parts))
")
seg_cwd=$(printf "${BOLD}${BLUE}%s${RESET}" "$display_cwd")

# 2. Git branch
if [ -n "$branch" ]; then
  seg_git=$(printf "${GREEN} %s${RESET}" "$branch")
else
  seg_git=""
fi

# 3. Model
if [ -n "$model" ]; then
  seg_model=$(printf "${MAGENTA}%s${RESET}" "$model")
else
  seg_model=""
fi

# 4. Context window
if [ -n "$used" ] && [ "$used" != "None" ]; then
  col=$(pct_color "$used")
  used_int=$(printf "%.0f" "$used")
  seg_ctx=$(printf "${col}ctx %s%%${RESET}" "$used_int")
else
  seg_ctx=$(printf "${DIM}ctx -${RESET}")
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
  if [ -n "$five_h_reset" ] && [ "$five_h_reset" != "None" ]; then
    seg_5h=$(printf "${col}5h %s%% ${DIM}(%s)${RESET}" "$fh_int" "$five_h_reset")
  else
    seg_5h=$(printf "${col}5h %s%%${RESET}" "$fh_int")
  fi
fi

# 7. 7-day rate limit
seg_7d=""
if [ -n "$seven_d_pct" ] && [ "$seven_d_pct" != "None" ]; then
  col=$(pct_color "$seven_d_pct")
  sd_int=$(printf "%.0f" "$seven_d_pct")
  if [ -n "$seven_d_reset" ] && [ "$seven_d_reset" != "None" ]; then
    seg_7d=$(printf "${col}7d %s%% ${DIM}(%s)${RESET}" "$sd_int" "$seven_d_reset")
  else
    seg_7d=$(printf "${col}7d %s%%${RESET}" "$sd_int")
  fi
fi

# 8. Session name
if [ -n "$session_name" ]; then
  seg_session=$(printf "${DIM}${WHITE}\"%s\"${RESET}" "$session_name")
else
  seg_session=""
fi

# --- Assemble ---
SEP=$(printf "${DIM} | ${RESET}")

line="$seg_cwd"
[ -n "$seg_git" ]     && line="$line${SEP}$seg_git"
[ -n "$seg_model" ]   && line="$line${SEP}$seg_model"
[ -n "$seg_ctx" ]     && line="$line${SEP}$seg_ctx"
[ -n "$seg_5h" ]      && line="$line${SEP}$seg_5h"
[ -n "$seg_7d" ]      && line="$line${SEP}$seg_7d"
[ -n "$seg_session" ] && line="$line${SEP}$seg_session"
[ -n "$seg_cost" ]    && line="$line${SEP}$seg_cost"

printf '%s\n' "$line"

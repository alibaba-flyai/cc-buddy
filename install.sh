#!/usr/bin/env bash
# cc-teacher installer

set -e

BASE_URL="https://claude.io.alibaba-inc.com"

# ── Resolve plugin directory ──────────────────────────────────────────────────
# When run as a file (./install.sh or bash install.sh from the repo), use the
# script's own directory so developers get live edits without reinstalling.
# When piped via curl | bash, $0 is "bash" and the script has no on-disk path,
# so download the hook files to a fixed location instead.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-install.sh}")" 2>/dev/null && pwd || echo ".")"

if [[ -f "$_SCRIPT_DIR/hooks-handlers/pre-tool-use.py" ]]; then
  PLUGIN_DIR="$_SCRIPT_DIR"
else
  PLUGIN_DIR="$HOME/.claude/cc-teacher"
  mkdir -p "$PLUGIN_DIR/hooks-handlers" "$PLUGIN_DIR/knowledge"
  curl -fsSL "$BASE_URL/hooks-handlers/pre-tool-use.py" \
    -o "$PLUGIN_DIR/hooks-handlers/pre-tool-use.py"
  curl -fsSL "$BASE_URL/knowledge/classifier.py" \
    -o "$PLUGIN_DIR/knowledge/classifier.py"
fi

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  ACCENT=$'\033[38;2;217;121;89m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  ACCENT=""
  BOLD=""
  RESET=""
fi

printf '\n'
printf '  %s%-10s%s\n' "$ACCENT" "/\\   /\\" "$RESET"
printf '  %s%-10s%s\n' "$ACCENT" "( o   o )" "$RESET"
printf '  %s%-10s%s\n' "$ACCENT" " ( ^_^ )" "$RESET"
printf '  %s%-10s%s   %scc-teacher%s\n' "$ACCENT" " /     \\" "$RESET" "$BOLD" "$RESET"
printf '  %s%-10s%s   Claude Code plugin\n\n' "$ACCENT" "(_)   (_)" "$RESET"

# ── Register hooks in ~/.claude/settings.json ────────────────────────────────

mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
[[ -f "$SETTINGS" ]] || echo '{}' >"$SETTINGS"

python3 - "$PLUGIN_DIR" "$SETTINGS" <<'PYEOF'
import json, sys
plugin_dir, settings_file = sys.argv[1], sys.argv[2]

hook_cmd = f"python3 {plugin_dir}/hooks-handlers/pre-tool-use.py"
legacy_start_cmd = f"bash {plugin_dir}/hooks-handlers/session-start.sh"

with open(settings_file) as f:
    s = json.load(f)

hooks = s.setdefault("hooks", {})

def _drop_commands(entries, blocked_commands):
    result = []
    for entry in entries:
        hs = [h for h in entry.get("hooks", [])
              if h.get("command") not in blocked_commands]
        if hs:
            result.append({**entry, "hooks": hs})
    return result

def _clean_stale(entries, valid_paths):
    """Remove entries whose handler file is missing and not part of current install."""
    import os
    result = []
    for entry in entries:
        hs = [h for h in entry.get("hooks", [])
              if not (h.get("command", "").split()[0] in ("python3", "bash")
                      and h["command"].split()[-1] not in valid_paths
                      and not os.path.exists(h["command"].split()[-1]))]
        if hs:
            result.append({**entry, "hooks": hs})
    return result

valid_paths = {f"{plugin_dir}/hooks-handlers/pre-tool-use.py"}
hooks["SessionStart"] = _drop_commands(hooks.get("SessionStart", []), {legacy_start_cmd})
hooks["SessionStart"] = _clean_stale(hooks["SessionStart"], valid_paths)
if not hooks["SessionStart"]:
    hooks.pop("SessionStart")

hooks["PreToolUse"] = _clean_stale(hooks.get("PreToolUse", []), valid_paths)

# PreToolUse
pretool = hooks.setdefault("PreToolUse", [])
if not any(
    h.get("command") == hook_cmd
    for entry in pretool
    for h in entry.get("hooks", [])
):
    pretool.append({
        "matcher": "Bash|Edit|Write|MultiEdit",
        "hooks": [{"type": "command", "command": hook_cmd, "timeout": 35}],
    })

with open(settings_file, "w") as f:
    json.dump(s, f, indent=2)
PYEOF

echo "  ✓ cc-teacher is ready. Start a new Claude Code session."
echo ""

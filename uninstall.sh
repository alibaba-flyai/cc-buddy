#!/usr/bin/env bash
# cc-teacher uninstaller

set -e

SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
	echo "  nothing to remove"
	exit 0
fi

python3 - "$SETTINGS" <<'PYEOF'
import json, sys

settings_file = sys.argv[1]

with open(settings_file) as f:
    s = json.load(f)

hooks = s.get("hooks", {})

def _is_cc_teacher(cmd: str) -> bool:
    return "pre-tool-use.py" in cmd or "session-start.sh" in cmd

for key in list(hooks.keys()):
    entries = hooks.get(key, [])
    for entry in entries:
        entry["hooks"] = [
            h for h in entry.get("hooks", [])
            if not _is_cc_teacher(h.get("command", ""))
        ]
    hooks[key] = [e for e in entries if e.get("hooks")]
    if not hooks[key]:
        hooks.pop(key)

# remove from localPlugins if present
local = s.get("localPlugins", [])
s["localPlugins"] = [p for p in local if not p.rstrip("/").endswith("cc-teacher")]

with open(settings_file, "w") as f:
    json.dump(s, f, indent=2)
PYEOF

# clean up downloaded plugin files if they exist
if [[ -d "$HOME/.claude/cc-teacher" ]]; then
    rm -rf "$HOME/.claude/cc-teacher"
fi

echo "  ✓ cc-teacher removed"
echo "    Changes apply in the next Claude Code session."
echo ""

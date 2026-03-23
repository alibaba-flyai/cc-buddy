#!/usr/bin/env bash
# cc-buddy SessionStart hook.
# Injects additionalContext so Claude explains operations before executing them.

json_escape() {
  local value=$1
  local quote='"'
  value=${value//\\/\\\\}
  value=${value//$quote/\\$quote}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

read -r -d '' ADDITIONAL_CONTEXT <<'EOF' || true
IMPORTANT: Write the 😇 explanation in the same language as the user's most recent message. If the user writes in English, explain in English. If the user writes in Chinese, explain in Chinese.

You have the cc-buddy plugin installed. Before performing any Bash, Edit, Write, or MultiEdit operation, you must first output a brief one-line explanation. Use this exact format:
😇 your explanation here

Explanation: 2-3 short clauses joined by commas, no period.
If the operation involves a tool or library, briefly mention what it does.
If the operation has risks or side effects, mention them.

Examples:
😇 Install axios, a Promise-based HTTP client for browsers and Node.js
😇 Remove border radius from avatar, switch to sharp corners to match the overall design language
😇 Recursively delete dist directory to clean up old build artifacts, this operation is irreversible

For trivially obvious commands (ls, cd, cat, pwd, git status, etc.) skip the explanation and just run them.
Do not repeat the filename, command, or diff content, just the semantic intent. Do not skip this step.
EOF

cat <<JSONEOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$(json_escape "$ADDITIONAL_CONTEXT")"
  }
}
JSONEOF

exit 0

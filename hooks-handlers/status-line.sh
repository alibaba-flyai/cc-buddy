#!/usr/bin/env bash
# cc-teacher status line: displays pending edit explanations
# Polled by Claude Code via statusLine config in settings.json

STATUS_FILE="$HOME/.claude/cc_teacher_status.txt"
TTL=60

if [ ! -f "$STATUS_FILE" ]; then
    exit 0
fi

ts=$(head -1 "$STATUS_FILE")
now=$(date +%s)

if [ $((now - ts)) -gt $TTL ]; then
    rm -f "$STATUS_FILE"
    exit 0
fi

explanation=$(tail -n +2 "$STATUS_FILE")
if [ -n "$explanation" ]; then
    short=$(echo "$explanation" | head -1 | cut -c1-120)
    printf '\033[38;2;217;121;89m☻\033[0m %s' "$short"
fi

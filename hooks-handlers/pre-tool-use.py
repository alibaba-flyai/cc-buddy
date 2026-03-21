#!/usr/bin/env python3
"""
cc-teacher PreToolUse hook.

On first encounter of a non-trivial operation:
  - Calls an LLM API to generate a contextual explanation.
  - Returns a structured allow decision with a user-facing warning message.
  - The tool call continues without interruption.

On subsequent encounters within the same session: exits 0 (no interruption).
"""

import hashlib
import json
import os
import random
import re
import sys
import textwrap
import urllib.request
from datetime import datetime

_PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _PLUGIN_ROOT)

from knowledge.classifier import classify_bash, classify_code
from knowledge.llm_client import LLM_API_URL, LLM_MODEL, LLM_TIMEOUT, get_api_key, detect_language

ACCENT = "\033[38;2;217;121;89m"
RESET = "\033[0m"


# ---------------------------------------------------------------------------
# Session state
# ---------------------------------------------------------------------------

def _state_file(session_id: str) -> str:
    return os.path.expanduser(f"~/.claude/cc_teacher_state_{session_id}.json")


def _session_key(data: dict) -> str:
    session_id = str(data.get("session_id", "")).strip()
    if session_id:
        return re.sub(r"[^A-Za-z0-9._-]", "_", session_id)

    transcript_path = str(data.get("transcript_path", "")).strip()
    if transcript_path:
        digest = hashlib.sha256(transcript_path.encode()).hexdigest()[:16]
        return f"transcript_{digest}"

    return "default"


def _normalize_command_for_key(command: str) -> str:
    return " ".join(command.strip().split())


def _cleanup_old_states():
    try:
        state_dir = os.path.expanduser("~/.claude")
        cutoff = datetime.now().timestamp() - 30 * 24 * 3600
        for fname in os.listdir(state_dir):
            if fname.startswith("cc_teacher_state_") and fname.endswith(".json"):
                fpath = os.path.join(state_dir, fname)
                try:
                    if os.path.getmtime(fpath) < cutoff:
                        os.remove(fpath)
                except (OSError, IOError):
                    pass
    except Exception:
        pass


def _load_state(session_id: str) -> set:
    path = _state_file(session_id)
    if os.path.exists(path):
        try:
            with open(path) as f:
                return set(json.load(f))
        except (json.JSONDecodeError, IOError):
            pass
    return set()


def _save_state(session_id: str, keys: set):
    path = _state_file(session_id)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(list(keys), f)
    except IOError:
        pass


# ---------------------------------------------------------------------------
# LLM call
# ---------------------------------------------------------------------------

def _call_llm(operation: str, lang_hint: str) -> str:
    """
    Ask the LLM to produce the final display text for this operation.
    Returns a ready-to-display string, or empty string to skip output entirely.
    """
    system_prompt = (
        f"You are a concise operations explainer shown inline in a developer's terminal. "
        f"Write 1-2 clauses explaining what this operation does. "
        f"Only return an empty string if the operation is completely self-descriptive and adds zero context (e.g. 'echo hello'). "
        f"Connect clauses with commas only — never use a period or full stop anywhere in the output. "
        f"If the operation installs or runs a named package or tool, briefly mention what it is for. "
        f"If there is a clearly relevant canonical URL, append it directly after the last word, "
        f"separated by a single space — no punctuation, no transition phrase before the URL. "
        f"Only mention risk or caveats when there is a real one worth calling out. "
        f"No bullet points, no headers, no markdown. Respond in: {lang_hint}.\n\n"
        f"Examples of correct output:\n"
        f"  安装 axios，一个基于 Promise 的 HTTP 客户端，用于浏览器和 Node.js 发起网络请求 https://axios-http.com\n"
        f"  对比 schema.prisma 与数据库现状，生成并执行迁移，同时更新 Prisma Client 类型 https://www.prisma.io/docs/orm/prisma-migrate\n"
        f"  Install axios, a Promise-based HTTP client for browsers and Node.js https://axios-http.com\n"
        f"  Delete files and directories recursively and without confirmation prompt https://man7.org/linux/man-pages/man1/rm.1.html"
    )

    payload = json.dumps({
        "model": LLM_MODEL,
        "stream": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": f"Operation: {operation}"},
        ],
    }).encode()

    req = urllib.request.Request(
        LLM_API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {get_api_key()}",
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=LLM_TIMEOUT) as resp:
        body = json.loads(resp.read().decode())

    return " ".join(body["choices"][0]["message"].get("content", "").strip().splitlines())


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def _build_card(text: str) -> str:
    # Pre-wrap so Claude Code's systemMessage renderer doesn't re-wrap with its own indentation.
    # Chinese chars are ~2 columns wide, so use a conservative width.
    lines = textwrap.wrap(text.strip(), width=88, break_long_words=False, break_on_hyphens=False)
    if not lines:
        return ""
    return f"{ACCENT}☻{RESET} " + "\n  ".join(lines)


def _emit_allow_message(message: str):
    card = _build_card(message)
    additional_context = (
        "cc-teacher has already explained this operation to the user.\n"
        "Do not repeat or paraphrase that explanation unless the user asks for it.\n"
        "Focus on the actual tool result.\n\n"
        f"{card}"
    )
    json.dump({
        "continue": True,
        "suppressOutput": False,
        "systemMessage": f"\n{card}\n",
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": message,
            "additionalContext": additional_context,
        },
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------

def _extract_edit_content(tool_name: str, tool_input: dict) -> tuple:
    """Returns (old, new) strings for the edit."""
    if tool_name == "Write":
        return "", tool_input.get("content", "")
    if tool_name == "Edit":
        return tool_input.get("old_string", ""), tool_input.get("new_string", "")
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits", [])
        old = " ".join(e.get("old_string", "") for e in edits)
        new = " ".join(e.get("new_string", "") for e in edits)
        return old, new
    return "", ""


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if random.random() < 0.2:
        _cleanup_old_states()

    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        sys.exit(0)

    session_id = _session_key(data)
    tool_name  = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    rule        = None
    warning_key = None
    operation   = ""

    if tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)
        rule = classify_bash(command)
        if rule:
            warning_key = f"Bash:{_normalize_command_for_key(command)}"
            operation = command.strip()

    elif tool_name in ("Edit", "Write", "MultiEdit"):
        file_path = tool_input.get("file_path", "")
        if not file_path:
            sys.exit(0)
        old_content, new_content = _extract_edit_content(tool_name, tool_input)
        rule = classify_code(file_path, new_content)
        if rule:
            content_hash = hashlib.md5((new_content or "").encode()).hexdigest()[:8]
            warning_key = f"{tool_name}:{file_path}:{content_hash}"
            old_snippet = old_content[:200].strip() if old_content else ""
            new_snippet = new_content[:200].strip() if new_content else ""
            if old_snippet and new_snippet:
                operation = f"{file_path}\nbefore: {old_snippet}\nafter: {new_snippet}"
            elif new_snippet:
                operation = f"{file_path}\n{new_snippet}"
            else:
                operation = file_path

    if not rule or not warning_key:
        sys.exit(0)

    lang = detect_language(data)

    try:
        text = _call_llm(operation, lang)
        if not text.strip():
            sys.exit(0)
        output = text.strip()
    except Exception:
        output = operation

    _emit_allow_message(output)
    sys.exit(0)


if __name__ == "__main__":
    main()

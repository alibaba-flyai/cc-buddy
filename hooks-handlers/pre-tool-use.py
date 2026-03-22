#!/usr/bin/env python3
"""
cc-teacher PreToolUse hook.

For Bash commands:
  - Calls an external LLM to generate a contextual explanation.
  - Shows the explanation inline via systemMessage.

For Edit/Write/MultiEdit operations:
  - First attempt: blocks the edit, instructs Claude to explain first.
  - Second attempt (after Claude explains): allows the edit to proceed.
  - No external API call needed; Claude explains using its own intelligence.
"""

import json
import os
import sys
import textwrap
import time
import urllib.request

_PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _PLUGIN_ROOT)

from knowledge.classifier import classify_bash, classify_code
from knowledge.llm_client import LLM_API_URL, LLM_MODEL, LLM_TIMEOUT, get_api_key, detect_language

ACCENT = "\033[38;2;217;121;89m"
RESET = "\033[0m"

_STATE_DIR = os.path.expanduser("~/.claude")


# ---------------------------------------------------------------------------
# LLM call (Bash only)
# ---------------------------------------------------------------------------

def _call_llm(operation: str, lang_hint: str) -> str:
    """
    Ask the LLM to produce the final display text for this operation.
    Returns a ready-to-display string, or empty string to skip output entirely.
    """
    system_prompt = (
        f"You are a concise operations explainer shown inline in a developer's terminal. "
        f"Write 1-2 clauses explaining what this operation does. Always produce output; never return an empty string. "
        f"Connect clauses with commas only, never use a period or full stop anywhere in the output. "
        f"If the operation installs or runs a named package or tool, briefly mention what it is for. "
        f"If there is a clearly relevant canonical URL, append it directly after the last word, "
        f"separated by a single space, no punctuation, no transition phrase before the URL. "
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
# Edit state management
# ---------------------------------------------------------------------------

def _state_path(session_id: str) -> str:
    return os.path.join(_STATE_DIR, f"cc_teacher_state_{session_id}.json")


def _load_state(session_id: str) -> dict:
    path = _state_path(session_id)
    try:
        with open(path) as f:
            return json.load(f)
    except (IOError, json.JSONDecodeError):
        return {}


def _save_state(session_id: str, state: dict):
    path = _state_path(session_id)
    try:
        with open(path, "w") as f:
            json.dump(state, f)
    except IOError:
        pass


def _is_edit_explained(session_id: str, file_path: str) -> bool:
    """Check if this file was already blocked (Claude should have explained it)."""
    state = _load_state(session_id)
    ts = state.get(file_path)
    if ts and (time.time() - ts) < 120:
        return True
    return False


def _mark_edit_blocked(session_id: str, file_path: str):
    """Record that an edit to this file was blocked for explanation."""
    state = _load_state(session_id)
    now = time.time()
    state = {k: v for k, v in state.items() if now - v < 300}
    state[file_path] = now
    _save_state(session_id, state)


def _clear_edit_key(session_id: str, file_path: str):
    """Remove the key after allowing the edit."""
    state = _load_state(session_id)
    state.pop(file_path, None)
    _save_state(session_id, state)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def _build_card(text: str) -> str:
    lines = textwrap.wrap(text.strip(), width=88, break_long_words=False, break_on_hyphens=False)
    if not lines:
        return ""
    return f"{ACCENT}☻{RESET} " + "\n  ".join(lines)


def _emit_bash(message: str):
    """Emit explanation for Bash commands (inline display via systemMessage)."""
    card = _build_card(message)
    json.dump({
        "continue": True,
        "suppressOutput": False,
        "systemMessage": f"\n{card}\n",
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": (
                "cc-teacher has already explained this operation to the user.\n"
                "Do not repeat or paraphrase that explanation unless the user asks for it.\n"
                "Focus on the actual tool result.\n\n"
                f"{card}"
            ),
        },
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def _emit_edit_block(file_path: str, operation: str, lang: str):
    """Block an edit and instruct Claude to explain first, then re-propose."""
    lang_instruction = "用中文" if "Chinese" in lang else "in English"
    json.dump({
        "continue": False,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": (
                f"cc-teacher paused this edit to {file_path} for user awareness. "
                f"Before re-proposing this edit, you MUST explain {lang_instruction} in 1-2 concise sentences "
                f"what this change does and why. Then immediately re-propose the exact same edit. "
                f"Do not apologize, do not ask for permission, just explain then re-propose.\n\n"
                f"Operation details:\n{operation}"
            ),
        },
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def _emit_edit_allow():
    """Allow an edit that was previously blocked and explained by Claude."""
    json.dump({
        "continue": True,
        "suppressOutput": False,
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": (
                "cc-teacher has verified this edit was explained. Proceed normally.\n"
                "Do not repeat the explanation unless the user asks."
            ),
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
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name  = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    session_id = data.get("session_id", "default")

    if tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)
        rule = classify_bash(command)
        if not rule:
            sys.exit(0)

        lang = detect_language(data)
        try:
            text = _call_llm(command.strip(), lang)
            output = text.strip() or command.strip()
        except Exception:
            output = command.strip()
        _emit_bash(output)

    elif tool_name in ("Edit", "Write", "MultiEdit"):
        file_path = tool_input.get("file_path", "")
        if not file_path:
            sys.exit(0)
        old_content, new_content = _extract_edit_content(tool_name, tool_input)
        rule = classify_code(file_path, new_content)
        if not rule:
            sys.exit(0)

        if _is_edit_explained(session_id, file_path):
            _clear_edit_key(session_id, file_path)
            _emit_edit_allow()
        else:
            _mark_edit_blocked(session_id, file_path)
            old_snippet = old_content[:200].strip() if old_content else ""
            new_snippet = new_content[:200].strip() if new_content else ""
            if old_snippet and new_snippet:
                operation = f"{file_path}\nbefore: {old_snippet}\nafter: {new_snippet}"
            elif new_snippet:
                operation = f"{file_path}\n{new_snippet}"
            else:
                operation = file_path
            lang = detect_language(data)
            _emit_edit_block(file_path, operation, lang)

    sys.exit(0)


if __name__ == "__main__":
    main()

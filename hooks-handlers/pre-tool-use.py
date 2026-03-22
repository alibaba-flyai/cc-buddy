#!/usr/bin/env python3
"""
cc-teacher PreToolUse hook.

Bash:
  - Calls an external LLM for a contextual explanation.
  - Shows explanation inline via systemMessage.

Edit / Write / MultiEdit:
  - Calls an external LLM for a contextual explanation.
  - Writes explanation directly to /dev/tty (bypasses Claude Code capture).
  - Exits 0 so the normal permission dialog appears after the explanation.
"""

import json
import os
import sys
import textwrap
import urllib.request

_PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _PLUGIN_ROOT)

from knowledge.classifier import classify_bash, classify_code
from knowledge.llm_client import LLM_API_URL, LLM_MODEL, LLM_TIMEOUT, get_api_key, detect_language

ACCENT = "\033[38;2;217;121;89m"
RESET  = "\033[0m"


# ---------------------------------------------------------------------------
# LLM calls
# ---------------------------------------------------------------------------

def _call_llm(operation: str, lang_hint: str, system_prompt: str) -> str:
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


def _call_llm_bash(command: str, lang_hint: str) -> str:
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
    return _call_llm(command.strip(), lang_hint, system_prompt)


def _call_llm_edit(file_path: str, old: str, new: str, lang_hint: str) -> str:
    name = os.path.basename(file_path)
    system_prompt = (
        f"You are a concise code-change explainer shown inline in a developer's terminal. "
        f"Write 1-2 clauses explaining what this code change does semantically. "
        f"Always produce output; never return an empty string. "
        f"Connect clauses with commas only, never use a period or full stop anywhere in the output. "
        f"Focus on the intent and effect of the change, not the literal before/after strings. "
        f"No bullet points, no headers, no markdown. Respond in: {lang_hint}.\n\n"
        f"Examples of correct output:\n"
        f"  去除头像的圆角，改为直角样式\n"
        f"  将状态点颜色从绿色改为蓝色，统一在线状态的视觉风格\n"
        f"  Remove border radius from avatar, switching to sharp corners\n"
        f"  Add null check before accessing user.profile to prevent TypeError on unauthenticated requests"
    )
    old_snippet = old.strip()[:300]
    new_snippet = new.strip()[:300]
    operation = f"file: {name}\nbefore: {old_snippet}\nafter: {new_snippet}"
    return _call_llm(operation, lang_hint, system_prompt)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def _build_card(text: str) -> str:
    lines = textwrap.wrap(text.strip(), width=88, break_long_words=False, break_on_hyphens=False)
    if not lines:
        return ""
    return f"{ACCENT}☻{RESET} " + "\n  ".join(lines)


def _emit_bash(message: str):
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


def _emit_edit(message: str):
    card = _build_card(message)
    json.dump({
        "continue": True,
        "suppressOutput": False,
        "systemMessage": f"\n{card}\n",
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": (
                "cc-teacher has already shown the user a summary of this edit above.\n"
                "Do not repeat or paraphrase it unless the user asks.\n"
                f"{card}"
            ),
        },
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------

def _extract_edit_content(tool_name: str, tool_input: dict) -> tuple:
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

    hook_event = data.get("hook_event_name", "PreToolUse")
    tool_name  = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    if hook_event == "PreToolUse" and tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)
        if not classify_bash(command):
            sys.exit(0)

        lang = detect_language(data)
        try:
            text = _call_llm_bash(command.strip(), lang)
            output = text.strip() or command.strip()
        except Exception:
            output = command.strip()
        _emit_bash(output)

    elif hook_event == "PreToolUse" and tool_name in ("Edit", "Write", "MultiEdit"):
        file_path = tool_input.get("file_path", "")
        if not file_path:
            sys.exit(0)
        old_content, new_content = _extract_edit_content(tool_name, tool_input)
        if not classify_code(file_path, new_content):
            sys.exit(0)

        lang = detect_language(data)
        try:
            text = _call_llm_edit(file_path, old_content, new_content, lang)
            output = text.strip() or os.path.basename(file_path)
        except Exception:
            output = os.path.basename(file_path)
        _emit_edit(output)

    sys.exit(0)


if __name__ == "__main__":
    main()

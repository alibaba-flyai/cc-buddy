#!/usr/bin/env python3
"""
cc-teacher PermissionRequest hook.

Injects an explanation into the permission dialog so users in "ask each time"
mode get context before they decide whether to allow the operation.
"""

import json
import sys
import textwrap
import urllib.request

ACCENT = "\033[38;2;217;121;89m"
RESET  = "\033[0m"


def _build_card(text: str) -> str:
    lines = textwrap.wrap(text.strip(), width=88, break_long_words=False, break_on_hyphens=False)
    if not lines:
        return ""
    return f"{ACCENT}☻{RESET} " + "\n  ".join(lines)

_PLUGIN_ROOT = __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__)))
sys.path.insert(0, _PLUGIN_ROOT)

from knowledge.classifier import classify_bash, classify_code
from knowledge.llm_client import LLM_API_URL, LLM_MODEL, LLM_TIMEOUT, get_api_key, detect_language


def _call_llm(operation: str, lang_hint: str) -> str:
    system_prompt = (
        f"You are a concise operations explainer shown inside a permission dialog. "
        f"Write at most one short clause explaining what this operation does. Always produce output; never return an empty string. "
        f"Connect clauses with commas only -- never use a period or full stop. "
        f"No bullet points, no headers, no markdown. Respond in: {lang_hint}."
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
    return body["choices"][0]["message"].get("content", "").strip()


def _extract_operation(tool_name: str, tool_input: dict) -> tuple:
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        if not command:
            return None, ""
        rule = classify_bash(command)
        return rule, command.strip() if rule else ""

    if tool_name == "WebFetch":
        url = tool_input.get("url", "")
        if not url:
            return None, ""
        return {"name": "operation"}, f"fetch {url}"

    if tool_name in ("Edit", "Write", "MultiEdit"):
        file_path = tool_input.get("file_path", "")
        if not file_path:
            return None, ""
        old = ""
        if tool_name == "Write":
            new = tool_input.get("content", "")
            content = new
        elif tool_name == "Edit":
            old = tool_input.get("old_string", "")
            new = tool_input.get("new_string", "")
            content = new
        else:
            old = ""
            new = " ".join(e.get("new_string", "") for e in tool_input.get("edits", []))
            content = new
        rule = classify_code(file_path, content)
        if rule:
            old_snippet = old[:200].strip() if old else ""
            new_snippet = new[:200].strip() if new else ""
            if old_snippet and new_snippet:
                operation = f"{file_path}\nbefore: {old_snippet}\nafter: {new_snippet}"
            elif new_snippet:
                operation = f"{file_path}\n{new_snippet}"
            else:
                operation = file_path
            return rule, operation
        return None, ""

    return None, ""


def main():
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name  = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    rule, operation = _extract_operation(tool_name, tool_input)
    if not rule or not operation:
        sys.exit(0)

    lang = detect_language(data)

    try:
        text = _call_llm(operation, lang)
        text = text or operation
    except Exception:
        text = operation

    card = _build_card(text)
    json.dump({
        "continue": True,
        "permissionDecisionReason": text,
        "systemMessage": f"\n{card}\n",
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.exit(0)


if __name__ == "__main__":
    main()

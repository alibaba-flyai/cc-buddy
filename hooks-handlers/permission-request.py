#!/usr/bin/env python3
"""
cc-teacher PermissionRequest hook.

Injects an explanation into the permission dialog so users in "ask each time"
mode get context before they decide whether to allow the operation.
"""

import base64
import json
import os
import sys
import urllib.request

_PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _PLUGIN_ROOT)

from knowledge.classifier import classify_bash, classify_code

LLM_API_URL = "https://api.vivgrid.com/v1/chat/completions"
LLM_MODEL   = "gpt-5.4-mini"
LLM_TIMEOUT = 30

_FALLBACK = base64.b64decode("***REDACTED_B64***").decode()


def _get_api_key() -> str:
    key = os.environ.get("CC_TEACHER_API_KEY", "").strip()
    if key and not key.startswith("fai-2"):
        return key
    conf = os.path.expanduser("~/.claude/cc_teacher.conf")
    if os.path.exists(conf):
        try:
            with open(conf) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("CC_TEACHER_API_KEY="):
                        key = line.split("=", 1)[1].strip()
                        if key and not key.startswith("fai-2"):
                            return key
        except IOError:
            pass
    return _FALLBACK


def _call_llm(operation: str) -> str:
    system_prompt = (
        "You are a concise operations explainer shown inside a permission dialog. "
        "Write at most one short clause explaining what this operation does. "
        "Connect clauses with commas only -- never use a period or full stop. "
        "If trivial or self-evident, return an empty string. "
        "No bullet points, no headers, no markdown."
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
            "Authorization": f"Bearer {_get_api_key()}",
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

    if tool_name in ("Edit", "Write", "MultiEdit"):
        file_path = tool_input.get("file_path", "")
        if not file_path:
            return None, ""
        if tool_name == "Write":
            content = tool_input.get("content", "")
        elif tool_name == "Edit":
            content = tool_input.get("new_string", "")
        else:
            content = " ".join(e.get("new_string", "") for e in tool_input.get("edits", []))
        rule = classify_code(file_path, content)
        if rule:
            snippet = content[:300].strip() if content else ""
            operation = f"{file_path}\n{snippet}" if snippet else file_path
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

    try:
        text = _call_llm(operation)
        if not text:
            sys.exit(0)
    except Exception:
        sys.exit(0)

    json.dump({"permissionDecisionReason": text}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.exit(0)


if __name__ == "__main__":
    main()

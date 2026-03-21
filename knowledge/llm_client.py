"""
Shared LLM configuration and helpers used by all cc-teacher hook handlers.
"""

import base64
import os
from typing import Optional

LLM_API_URL = "https://api.vivgrid.com/v1/chat/completions"
LLM_MODEL   = "gpt-5.4-mini"
LLM_TIMEOUT = 25  # seconds; hooks.json timeout is 40, leaving margin for startup overhead

_FALLBACK = base64.b64decode("***REDACTED_B64***").decode()


def get_api_key() -> str:
    """Priority: CC_TEACHER_API_KEY env > ~/.claude/cc_teacher.conf > fallback."""
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


def detect_language(data: dict) -> str:
    """Best-effort language detection from hook payload. Falls back to Chinese."""
    messages = data.get("messages") or data.get("transcript") or []
    for msg in reversed(messages):
        content = msg.get("content", "")
        if isinstance(content, str) and content.strip():
            cjk = sum(1 for c in content if "\u4e00" <= c <= "\u9fff")
            if cjk / max(len(content), 1) > 0.1:
                return "Chinese (Simplified)"
            if content.isascii():
                return "English"
    return "Chinese (Simplified)"

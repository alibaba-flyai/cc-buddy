"""
Operation classifier: determines which operations need LLM explanation.

Only maintains exemption lists for trivially simple operations.
Everything else is passed to the LLM to decide whether explanation is needed.
"""

import os
import re
from typing import Optional


# ---------------------------------------------------------------------------
# Simple command patterns -- skip LLM call entirely
# ---------------------------------------------------------------------------

SIMPLE_BASH_PATTERNS = [
    r"^ls(\s|$)",
    r"^pwd(\s|$)",
    r"^echo\s",
    r"^cd\s",
    r"^clear(\s|$)",
    r"^history(\s|$)",
    r"^date(\s|$)",
    r"^whoami(\s|$)",
    r"^uname(\s|$)",
    r"^env(\s|$)",
    r"^printenv(\s|$)",
]

SIMPLE_FILE_EXTENSIONS = {".md", ".txt", ".log", ".csv", ".lock"}
SIMPLE_FILE_NAMES = {"package-lock.json", "yarn.lock", "Pipfile.lock", "poetry.lock"}

# Returned as a truthy sentinel; content is unused today but kept as a dict
# so callers can attach metadata in the future without changing the interface.
_GENERIC_RULE: dict = {"name": "operation"}


def _is_simple_bash(command: str) -> bool:
    cmd = command.strip()
    return any(re.match(p, cmd, re.IGNORECASE) for p in SIMPLE_BASH_PATTERNS)


def _is_simple_file(file_path: str) -> bool:
    basename = os.path.basename(file_path)
    if basename in SIMPLE_FILE_NAMES:
        return True
    _, ext = os.path.splitext(file_path)
    return ext.lower() in SIMPLE_FILE_EXTENSIONS


def classify_bash(command: str) -> Optional[dict]:
    """Returns a rule dict if the command may need explanation, else None."""
    if not command or not command.strip():
        return None

    if "|" in command:
        import shlex
        try:
            tokens = shlex.split(command)
            segments_raw: list[str] = []
            current: list[str] = []
            for tok in tokens:
                if tok == "|":
                    segments_raw.append(" ".join(current))
                    current = []
                else:
                    current.append(tok)
            if current:
                segments_raw.append(" ".join(current))
            segments = [s.strip() for s in segments_raw if s.strip()]
        except ValueError:
            segments = [s.strip() for s in command.split("|")]

        if all(_is_simple_bash(seg) for seg in segments):
            return None
        return _GENERIC_RULE

    if _is_simple_bash(command.strip()):
        return None
    return _GENERIC_RULE


def classify_code(file_path: str, content: str = "") -> Optional[dict]:
    """Returns a rule dict if the file edit may need explanation, else None."""
    if not file_path:
        return None
    if _is_simple_file(file_path):
        return None
    return _GENERIC_RULE

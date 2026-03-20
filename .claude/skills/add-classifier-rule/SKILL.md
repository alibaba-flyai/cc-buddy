---
name: add-classifier-rule
description: Add a pattern to the cc-teacher exemption list so a trivial operation is no longer explained.
---

# Add Exemption Pattern

The LLM decides what to explain. Use this skill when cc-teacher is explaining something too obvious and you want to silence it.

## Steps

1. Add a regex to `SIMPLE_BASH_PATTERNS` in `knowledge/classifier.py`:
   ```python
   r"^my-command(\s|$)",
   ```

2. Verify it returns `None`:
   ```bash
   python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('my-command --flag'))"
   ```

3. Verify a non-trivial command still returns a rule dict:
   ```bash
   python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('docker compose up -d'))"
   ```

For file types, add to `SIMPLE_FILE_EXTENSIONS` (e.g. `".yaml"`) or `SIMPLE_FILE_NAMES` (e.g. `".eslintrc"`).

# CLAUDE.md - cc-teacher

**Purpose:** Rules for AI assistants working on the cc-teacher Claude Code plugin.

## Language

- Respond in Chinese at all times (follows global directive)
- NEVER use em dash (U+2014 —) in any output, code, or documentation. Use commas, colons, or semicolons instead

## What this project is

A Claude Code plugin. The PreToolUse hook (`hooks-handlers/pre-tool-use.py`) checks whether an
operation is in the exemption list, then calls an LLM to decide if explanation is needed and
generate it. `knowledge/classifier.py` maintains only the exemption list (`SIMPLE_BASH_PATTERNS`,
`SIMPLE_FILE_NAMES`, `SIMPLE_FILE_EXTENSIONS`) -- trivially obvious operations are skipped without
an LLM call; everything else is handled by the LLM.

## Critical rules

### NEVER
- Hardcode API keys in source files
- Modify `~/.claude/settings.json` directly -- only `install.sh` does that

### ALWAYS
- Verify exemption changes with: `python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('YOUR_COMMAND'))"`
- Keep `_FALLBACK` key obfuscated (base64); never store plaintext keys in code

## Quick commands

```bash
# Test a specific command against the classifier
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('docker compose up -d'))"

# Run the hook manually with a test payload
echo '{"session_id":"dev","tool_name":"Bash","tool_input":{"command":"npm install"}}' \
  | python3 hooks-handlers/pre-tool-use.py

# Verify no plaintext key in source
grep -r "fai-2" . --include="*.py" --include="*.sh"
```

## Verification

| Task | Command | Pass condition |
|---|---|---|
| Syntax check | `python3 -m py_compile hooks-handlers/pre-tool-use.py knowledge/classifier.py` | No output |
| Classifier change | `python3 -c "from knowledge.classifier import classify_bash, classify_code"` | No import error |
| Hook change | `echo '{"session_id":"x","tool_name":"Bash","tool_input":{"command":"ls"}}' \| python3 hooks-handlers/pre-tool-use.py; echo $?` | exit 0 |
| Key not leaked | `grep -r "fai-2" . --include="*.py" --include="*.sh"` | No matches |

## File map

| File | Purpose |
|---|---|
| `knowledge/classifier.py` | Exemption list only -- add patterns here to silence over-eager LLM explanations |
| `hooks-handlers/pre-tool-use.py` | Hook runtime: classify, call LLM, emit warning, allow |
| `hooks/hooks.json` | Hook handler declarations (uses CLAUDE_PLUGIN_ROOT, not relied on for local installs) |
| `install.sh` | Registers hooks with absolute paths in `~/.claude/settings.json` |
| `uninstall.sh` | Removes hooks from `~/.claude/settings.json` |

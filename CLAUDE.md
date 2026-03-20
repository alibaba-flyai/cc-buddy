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
- Modify Claude Code plugin installation state manually when plugin commands or `--plugin-dir` can be used
- Reintroduce curl-based install or uninstall flows, this repo ships through GitHub marketplace only

### ALWAYS
- Verify exemption changes with: `python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('YOUR_COMMAND'))"`
- Keep `_FALLBACK` key obfuscated (base64); never store plaintext keys in code
- Keep README concise, installation-first, and free of redundant explanation, prefer one primary example over multiple similar examples
- When plugin behavior or distribution changes in a user-visible way, bump versions in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
- Test hook behavior with a command that actually triggers `PreToolUse`, read-only search and file reads are not sufficient to validate the plugin
- Ignore legacy internal `fai-2` keys when updating auth logic, do not let old local config silently override the current provider

## Quick commands

```bash
# Test a specific command against the classifier
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('docker compose up -d'))"

# Run the hook manually with a test payload
echo '{"session_id":"dev","tool_name":"Bash","tool_input":{"command":"npm install"}}' \
  | python3 hooks-handlers/pre-tool-use.py

# Verify no plaintext key in source
grep -r "viv-ccteacher-" . --include="*.py" --include="*.sh"

# Validate plugin manifests
claude plugins validate .
```

## Verification

| Task | Command | Pass condition |
|---|---|---|
| Syntax check | `python3 -m py_compile hooks-handlers/pre-tool-use.py knowledge/classifier.py` | No output |
| Classifier change | `python3 -c "from knowledge.classifier import classify_bash, classify_code"` | No import error |
| Hook change | `echo '{"session_id":"x","tool_name":"Bash","tool_input":{"command":"ls"}}' \| python3 hooks-handlers/pre-tool-use.py; echo $?` | exit 0 |
| Key not leaked | `grep -r "viv-ccteacher-" . --include="*.py" --include="*.sh"` | No matches |

## File map

| File | Purpose |
|---|---|
| `knowledge/classifier.py` | Exemption list only -- add patterns here to silence over-eager LLM explanations |
| `hooks-handlers/pre-tool-use.py` | Hook runtime: classify, call LLM, emit warning, allow |
| `hooks/hooks.json` | Hook handler declarations (uses CLAUDE_PLUGIN_ROOT, not relied on for local installs) |
| `.claude-plugin/plugin.json` | Plugin manifest consumed by Claude Code |
| `.claude-plugin/marketplace.json` | Marketplace manifest for GitHub distribution |

## Release notes

- Marketplace name is `flyai`, install target is `cc-teacher@flyai`
- User-facing plugin updates require version bumps, otherwise Claude Code may continue using cached plugin content
- If users report "the old version is still installed", first check marketplace update, plugin update, reload, and current manifest version

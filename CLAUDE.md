# CLAUDE.md - cc-teacher

**Purpose:** Rules for AI assistants working on the cc-teacher Claude Code plugin.

## Language

- Respond in Chinese at all times (follows global directive)
- NEVER use em dash (U+2014 —) in any output, code, or documentation. Use commas, colons, or semicolons instead

## What this project is

A Claude Code plugin with a `PreToolUse` hook. For Bash commands, it calls an external LLM and
shows the explanation inline via `systemMessage`. For Edit/Write/MultiEdit operations, it blocks
the first attempt and instructs Claude to explain the change, then allows the re-proposed edit
so the explanation appears above the diff dialog (no external API call needed for edits).
The exemption list lives in `knowledge/classifier.py`; shared LLM config in `knowledge/llm_client.py`.

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
- Current LLM provider is `api.vivgrid.com`, model `gpt-5.4-mini`; ignore legacy `fai-2` keys, do not let old local config silently override

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
| Syntax check | `python3 -m py_compile hooks-handlers/pre-tool-use.py knowledge/classifier.py knowledge/llm_client.py` | No output |
| Classifier change | `python3 -c "from knowledge.classifier import classify_bash, classify_code"` | No import error |
| Hook change | `echo '{"session_id":"x","tool_name":"Bash","tool_input":{"command":"ls"}}' \| python3 hooks-handlers/pre-tool-use.py; echo $?` | exit 0 |
| Key not leaked | `grep -r "viv-ccteacher-" . --include="*.py" --include="*.sh"` | No matches |
| LLM prompt change | `bash test.sh` | 通过: 11  失败: 0 |

## File map

| File | Purpose |
|---|---|
| `knowledge/classifier.py` | Exemption list only -- add patterns here to silence over-eager LLM explanations |
| `knowledge/llm_client.py` | Shared LLM config, `get_api_key()`, `detect_language()` |
| `hooks-handlers/pre-tool-use.py` | PreToolUse hook: Bash uses external LLM + systemMessage; Edit uses block/explain/re-propose flow |
| `hooks/hooks.json` | Hook handler declarations (uses CLAUDE_PLUGIN_ROOT, not relied on for local installs) |
| `test.sh` | Local test runner -- validates exempted and explained commands without installing the plugin |
| `.claude-plugin/plugin.json` | Plugin manifest consumed by Claude Code |
| `.claude-plugin/marketplace.json` | Marketplace manifest for GitHub distribution |

## Release notes

- Marketplace name is `flyai`, install target is `cc-teacher@flyai`
- User-facing plugin updates require version bumps, otherwise Claude Code may continue using cached plugin content
- If users report "the old version is still installed", first check marketplace update, plugin update, reload, and current manifest version
- `settings.local.json` sets `"enabledPlugins": {}` intentionally: disables cc-teacher in this project directory to prevent self-explanation loops during development

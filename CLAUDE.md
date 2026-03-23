# CLAUDE.md - cc-teacher

**Purpose:** Rules for AI assistants working on the cc-teacher Claude Code plugin.

## Language

- Respond in Chinese at all times (follows global directive)
- NEVER use em dash (U+2014 —) in any output, code, or documentation. Use commas, colons, or semicolons instead

## What this project is

A Claude Code plugin with a single `SessionStart` hook. It injects `additionalContext` at session start so Claude explains each Bash, Edit, Write, and MultiEdit operation in its own output before executing it. No external LLM dependency; Claude itself generates the explanations.

## Critical rules

### NEVER
- Introduce external LLM calls or API keys; this plugin relies solely on Claude's own output
- Modify Claude Code plugin installation state manually when plugin commands or `--plugin-dir` can be used
- Reintroduce curl-based install or uninstall flows, this repo ships through GitHub marketplace only

### ALWAYS
- Keep README concise, installation-first, and free of redundant explanation, prefer one primary example over multiple similar examples
- When plugin behavior or distribution changes in a user-visible way, bump versions in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
- Test hook behavior with `bash test.sh`; read-only search and file reads are not sufficient to validate the plugin
- This plugin uses SessionStart + additionalContext only; do not introduce external LLM calls or API keys

## Quick commands

```bash
# Run the SessionStart hook manually
bash hooks-handlers/session-start.sh

# Run test suite
bash test.sh

# Validate plugin manifests
claude plugins validate .
```

## Verification

| Task | Command | Pass condition |
|---|---|---|
| SessionStart hook | `bash hooks-handlers/session-start.sh \| python3 -c "import sys,json; print('ok' if 'additionalContext' in json.load(sys.stdin).get('hookSpecificOutput','') else 'fail')"` | ok |
| Full test suite | `bash test.sh` | 通过: 10  失败: 0 |

## File map

| File | Purpose |
|---|---|
| `hooks-handlers/session-start.sh` | SessionStart hook: injects additionalContext so Claude explains operations before executing |
| `hooks/hooks.json` | Hook handler declarations |
| `test.sh` | Local test runner |
| `.claude-plugin/plugin.json` | Plugin manifest consumed by Claude Code |
| `.claude-plugin/marketplace.json` | Marketplace manifest for GitHub distribution |

## Release notes

- Marketplace name is `flyai`, install target is `cc-teacher@flyai`
- User-facing plugin updates require version bumps, otherwise Claude Code may continue using cached plugin content
- If users report "the old version is still installed", first check marketplace update, plugin update, reload, and current manifest version
- `settings.local.json` sets `"enabledPlugins": {}` intentionally: disables cc-teacher in this project directory to prevent self-explanation loops during development

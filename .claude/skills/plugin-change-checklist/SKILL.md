---
name: plugin-change-checklist
description: Finalize a cc-teacher plugin change by updating user-facing docs, versions, validation, and rollout details.
---

# Plugin Change Checklist

Use this skill when a change affects plugin behavior, distribution, provider config, or the user-facing install experience.

## Goals

- Keep the plugin shippable through GitHub marketplace
- Keep README short and installation-first
- Make sure Claude Code can detect the update
- Catch hook regressions before push

## Checklist

1. If behavior changed in a way users need to receive, bump both versions:
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`

2. Keep README focused:
   - Prefer one primary example
   - Prefer direct CLI commands over extra prose
   - Avoid repeating behavior that is already explained elsewhere
   - Do not reintroduce curl-based install instructions

3. If provider or auth logic changed:
   - Keep fallback keys obfuscated, for example base64
   - Do not commit plaintext keys
   - Preserve env var and local config override behavior when appropriate
   - Ignore legacy `fai-2` keys so old internal config does not break the current provider

4. Validate the plugin:
   ```bash
   claude plugins validate .
   python3 -m py_compile hooks-handlers/pre-tool-use.py knowledge/classifier.py
   ```

5. Test a real hook path, not just read-only actions:
   ```bash
   echo '{"session_id":"dev","tool_name":"Bash","tool_input":{"command":"npm install axios"},"messages":[{"content":"帮我安装一个好用的请求库"}]}' \
     | python3 hooks-handlers/pre-tool-use.py
   ```

6. When users say updates are not visible locally, check in this order:
   - `/plugin marketplace update flyai`
   - `/plugin update cc-teacher@flyai`
   - `/reload-plugins`
   - if still stale, confirm the manifest version actually changed

## Output expectation

When finishing a change, report:

- whether versions were bumped
- what README text changed
- what validation commands passed
- what users should run locally if they need to refresh the plugin

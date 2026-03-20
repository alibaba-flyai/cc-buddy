# Python Rules

## Before completing Python changes
- Syntax check: `python3 -m py_compile hooks-handlers/pre-tool-use.py knowledge/classifier.py`
- Smoke test: `echo '{"session_id":"test","tool_name":"Bash","tool_input":{"command":"ls"}}' | python3 hooks-handlers/pre-tool-use.py; echo $?` -- expect exit 0
- No new dependencies: stdlib only (`json`, `os`, `re`, `base64`, `urllib.request`, `urllib.parse`, `textwrap`)

## Coding conventions
- Type hints on all public functions
- Private helpers prefixed with `_`
- `Optional[X]` return type when a function may return `None`
- No f-string expressions with side effects

## Error handling
- Hook functions must never raise to the caller -- catch all exceptions and either
  fall back silently or `sys.exit(0)` to avoid blocking Claude
- LLM call failures fall back to a minimal local explanation, never crash

## Testing a hook change
```bash
echo '{"session_id":"test","tool_name":"Bash","tool_input":{"command":"docker compose up -d"}}' \
  | python3 hooks-handlers/pre-tool-use.py
# expect: exit 0, JSON allow decision on stdout

echo '{"session_id":"test","tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | python3 hooks-handlers/pre-tool-use.py
# expect: exit 0, no output
```

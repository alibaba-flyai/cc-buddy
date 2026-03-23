# Python Rules

## Before completing Python changes
- Syntax check: `python3 -m py_compile hooks-handlers/session-start.py`
- Smoke test: `echo '{"session_id":"test"}' | python3 hooks-handlers/session-start.py` -- expect exit 0, JSON with additionalContext on stdout
- No new dependencies: stdlib only (`json`, `os`, `sys`)

## Coding conventions
- Type hints on all public functions
- Private helpers prefixed with `_`
- No f-string expressions with side effects

## Error handling
- Hook functions must never raise to the caller -- catch all exceptions and `sys.exit(0)` to avoid blocking Claude

## Testing a hook change
```bash
bash test.sh
# expect: 通过: 10  失败: 0
```

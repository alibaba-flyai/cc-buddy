# Shell Rules

## Before completing hook changes
- Test: `bash test.sh` -- expect exit 0 and `失败: 0`
- Validate JSON output: `bash hooks-handlers/session-start.sh | python3 -c "import sys,json; json.load(sys.stdin)"`

## Error handling
- Hook scripts must always `exit 0` to avoid blocking Claude

## Testing a hook change
```bash
bash test.sh
# expect: exit 0 and 失败: 0
```

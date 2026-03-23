#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

SESSION_HOOK=(bash hooks-handlers/session-start.sh)
PASS=0
FAIL=0

pass() {
  echo "  PASS  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL  $1"
  FAIL=$((FAIL + 1))
}

echo ""
echo "=== SessionStart 应该输出 additionalContext ==="

result=$("${SESSION_HOOK[@]}" 2>/dev/null)
if grep -q '"additionalContext"' <<<"$result"; then
  pass "SessionStart outputs additionalContext"
else
  fail "SessionStart outputs additionalContext (got: $result)"
fi

echo ""
echo "=== additionalContext 应该包含关键指令 ==="

for keyword in "😇" "Bash" "Edit" "Write" "MultiEdit"; do
  if grep -q "$keyword" <<<"$result"; then
    pass "contains $keyword"
  else
    fail "missing $keyword"
  fi
done

echo ""
echo "=== 指令内容检查 ==="

if grep -q "same language as the user" <<<"$result"; then
  pass "adaptive language instruction"
else
  fail "adaptive language instruction"
fi

if grep -q "You have the cc-buddy" <<<"$result"; then
  pass "English instruction"
else
  fail "English instruction"
fi

echo ""
echo "=== JSON 格式合法 ==="

if printf '%s' "$result" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  pass "valid JSON"
else
  fail "invalid JSON"
fi

echo ""
echo "=== 退出码 ==="

if "${SESSION_HOOK[@]}" >/dev/null 2>&1; then
  pass "exit 0"
else
  fail "exit code != 0"
fi

echo ""
echo "=== hooks.json 应该正确声明 SessionStart ==="

if python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("hooks/hooks.json").read_text())
hook = data["hooks"]["SessionStart"][0]["hooks"][0]
assert hook["type"] == "command"
assert hook["command"] == 'bash "${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh"'
assert hook["timeout"] == 5
PY
then
  pass "hooks.json wiring"
else
  fail "hooks.json wiring"
fi

echo ""
echo "=== manifest 版本应该保持一致 ==="

if python3 - <<'PY'
import json
from pathlib import Path

plugin = json.loads(Path(".claude-plugin/plugin.json").read_text())
marketplace = json.loads(Path(".claude-plugin/marketplace.json").read_text())
assert plugin["version"] == marketplace["plugins"][0]["version"]
PY
then
  pass "plugin.json and marketplace.json versions match"
else
  fail "plugin.json and marketplace.json versions differ"
fi

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

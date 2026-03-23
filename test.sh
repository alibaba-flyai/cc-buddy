#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

SESSION_HOOK="bash hooks-handlers/session-start.sh"
PASS=0
FAIL=0

echo ""
echo "=== SessionStart 应该输出 additionalContext ==="

result=$($SESSION_HOOK 2>/dev/null)
if echo "$result" | grep -q '"additionalContext"'; then
  echo "  PASS  SessionStart outputs additionalContext"
  PASS=$((PASS+1))
else
  echo "  FAIL  SessionStart outputs additionalContext (got: $result)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== additionalContext 应该包含关键指令 ==="

for keyword in "☻" "Bash" "Edit" "Write" "MultiEdit"; do
  if echo "$result" | grep -q "$keyword"; then
    echo "  PASS  contains $keyword"
    PASS=$((PASS+1))
  else
    echo "  FAIL  missing $keyword"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== 中英文指令都包含 ==="

if echo "$result" | grep -q "你安装了"; then
  echo "  PASS  Chinese instruction"
  PASS=$((PASS+1))
else
  echo "  FAIL  Chinese instruction"
  FAIL=$((FAIL+1))
fi

if echo "$result" | grep -q "You have the cc-teacher"; then
  echo "  PASS  English instruction"
  PASS=$((PASS+1))
else
  echo "  FAIL  English instruction"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== JSON 格式合法 ==="

if echo "$result" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "  PASS  valid JSON"
  PASS=$((PASS+1))
else
  echo "  FAIL  invalid JSON"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 退出码 ==="

$SESSION_HOOK > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "  PASS  exit 0"
  PASS=$((PASS+1))
else
  echo "  FAIL  exit code != 0"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

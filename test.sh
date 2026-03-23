#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

SESSION_HOOK="python3 hooks-handlers/session-start.py"
PASS=0
FAIL=0

echo ""
echo "=== SessionStart 应该输出 additionalContext ==="

result=$(echo '{"session_id":"t"}' | $SESSION_HOOK 2>/dev/null)
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
echo "=== 中文指令检测 ==="

result_cn=$(echo '{"session_id":"t","messages":[{"role":"user","content":"你好"}]}' | $SESSION_HOOK 2>/dev/null)
if echo "$result_cn" | grep -q "你安装了"; then
  echo "  PASS  Chinese instruction"
  PASS=$((PASS+1))
else
  echo "  FAIL  Chinese instruction (got: $result_cn)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 英文指令检测 ==="

result_en=$(echo '{"session_id":"t","messages":[{"role":"user","content":"hello world"}]}' | $SESSION_HOOK 2>/dev/null)
if echo "$result_en" | grep -q "You have the cc-teacher"; then
  echo "  PASS  English instruction"
  PASS=$((PASS+1))
else
  echo "  FAIL  English instruction (got: $result_en)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 语法检查 ==="

if python3 -m py_compile hooks-handlers/session-start.py 2>/dev/null; then
  echo "  PASS  session-start.py syntax"
  PASS=$((PASS+1))
else
  echo "  FAIL  session-start.py syntax"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 退出码 ==="

echo '{}' | $SESSION_HOOK > /dev/null 2>&1
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

#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

HOOK="python3 hooks-handlers/pre-tool-use.py"
PASS=0
FAIL=0

# 清理上次测试留下的 state 文件
rm -f ~/.claude/cc_teacher_state_t.json \
       ~/.claude/cc_teacher_state_t2.json \
       ~/.claude/cc_teacher_state_t3.json \
       ~/.claude/cc_teacher_state_t4.json

run() {
  local label="$1"
  local payload="$2"
  local expect_output="$3"   # "yes" | "no"

  result=$(echo "$payload" | $HOOK 2>/dev/null)
  exit_code=$?

  if [ "$expect_output" = "yes" ]; then
    if echo "$result" | grep -q '"continue"'; then
      echo "  PASS  $label"
      PASS=$((PASS+1))
    else
      echo "  FAIL  $label (expected output, got none)"
      FAIL=$((FAIL+1))
    fi
  else
    if [ -z "$result" ] && [ "$exit_code" -eq 0 ]; then
      echo "  PASS  $label"
      PASS=$((PASS+1))
    else
      echo "  FAIL  $label (expected silence, got: $result)"
      FAIL=$((FAIL+1))
    fi
  fi
}

echo ""
echo "=== 应该静默 (exempted) ==="
run "ls"           '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"ls"}}' no
run "ls -la"       '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"ls -la"}}' no
run "git status"   '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"git status"}}' no
run "cat file"     '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"cat README.md"}}' no

echo ""
echo "=== 应该有输出 (explained) ==="
run "npm install"  '{"session_id":"t2","tool_name":"Bash","tool_input":{"command":"npm install"}}' yes
run "docker up"    '{"session_id":"t3","tool_name":"Bash","tool_input":{"command":"docker compose up -d"}}' yes
run "rm -rf"       '{"session_id":"t4","tool_name":"Bash","tool_input":{"command":"rm -rf dist"}}' yes

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

# 清理本次测试生成的 state 文件
rm -f ~/.claude/cc_teacher_state_t.json \
       ~/.claude/cc_teacher_state_t2.json \
       ~/.claude/cc_teacher_state_t3.json \
       ~/.claude/cc_teacher_state_t4.json

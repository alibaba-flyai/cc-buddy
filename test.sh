#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

HOOK="python3 hooks-handlers/pre-tool-use.py"
PASS=0
FAIL=0

# 清理上次测试留下的 state 文件
rm -f ~/.claude/cc_teacher_state_t.json \
       ~/.claude/cc_teacher_state_t2.json \
       ~/.claude/cc_teacher_state_t3.json \
       ~/.claude/cc_teacher_state_t4.json \
       ~/.claude/cc_teacher_state_t5.json \
       ~/.claude/cc_teacher_state_t6.json \
       ~/.claude/cc_teacher_state_t7.json \
       ~/.claude/cc_teacher_status.txt

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
run "Edit tsx"     '{"session_id":"t5","tool_name":"Edit","tool_input":{"file_path":"src/app.ts","old_string":"foo","new_string":"bar"}}' yes

echo ""
echo "=== 不应包含 permissionDecision (统一 status line) ==="

run_no_permission() {
  local label="$1"
  local payload="$2"
  result=$(echo "$payload" | $HOOK 2>/dev/null)
  if echo "$result" | grep -q '"continue"' && ! echo "$result" | grep -q '"permissionDecision"'; then
    echo "  PASS  $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $label (got: $result)"
    FAIL=$((FAIL+1))
  fi
}

run_no_permission "Bash no permissionDecision" \
  '{"session_id":"t6","tool_name":"Bash","tool_input":{"command":"pip install flask"}}'

run_no_permission "Edit no permissionDecision" \
  '{"session_id":"t7","tool_name":"Edit","tool_input":{"file_path":"src/app.ts","old_string":"foo","new_string":"bar"}}'

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

# 清理本次测试生成的 state 文件
rm -f ~/.claude/cc_teacher_state_t.json \
       ~/.claude/cc_teacher_state_t2.json \
       ~/.claude/cc_teacher_state_t3.json \
       ~/.claude/cc_teacher_state_t4.json \
       ~/.claude/cc_teacher_state_t5.json \
       ~/.claude/cc_teacher_state_t6.json \
       ~/.claude/cc_teacher_state_t7.json \
       ~/.claude/cc_teacher_status.txt

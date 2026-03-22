#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

HOOK="python3 hooks-handlers/pre-tool-use.py"
PASS=0
FAIL=0

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

run_continue() {
  local label="$1"
  local payload="$2"
  local expect_continue="$3"   # "true" | "false"

  result=$(echo "$payload" | $HOOK 2>/dev/null)

  if echo "$result" | grep -q "\"continue\": *$expect_continue"; then
    echo "  PASS  $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $label (expected continue=$expect_continue, got: $result)"
    FAIL=$((FAIL+1))
  fi
}

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

echo ""
echo "=== 应该静默 (exempted) ==="
run "ls"           '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"ls"}}' no
run "ls -la"       '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"ls -la"}}' no
run "git status"   '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"git status"}}' no
run "cat file"     '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"cat README.md"}}' no

echo ""
echo "=== Bash 应该有输出 (explained, continue=true) ==="
run "npm install"  '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"npm install"}}' yes
run "docker up"    '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"docker compose up -d"}}' yes
run "rm -rf"       '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"rm -rf dist"}}' yes

echo ""
echo "=== Edit 应该输出说明 (continue=true, systemMessage) ==="
run_continue "Edit tsx explain" \
  '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"src/app.ts","old_string":"foo","new_string":"bar"}}' \
  true

echo ""
echo "=== Edit 简单文件应该静默 ==="
run "Edit .md file" \
  '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"README.md","old_string":"foo","new_string":"bar"}}' \
  no

echo ""
echo "=== Bash 不应包含 permissionDecision ==="
run_no_permission "Bash no permissionDecision" \
  '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"pip install flask"}}'

echo ""
echo "=== && 复合命令应该有输出 ==="
run_continue "cd && rm explain" \
  '{"session_id":"t","tool_name":"Bash","tool_input":{"command":"cd /tmp && rm -rf dist"}}' \
  true

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

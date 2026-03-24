#!/usr/bin/env bash
# 本地调试脚本 -- 不需要安装插件，直接跑

# 前置检查：确保关键文件存在（这个阶段使用严格模式）
check_prerequisites() {
  local missing_files=()
  local required_files=(
    "hooks-handlers/session-start.sh"
    "hooks/hooks.json"
    ".claude-plugin/plugin.json"
    ".claude-plugin/marketplace.json"
  )
  
  for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
      missing_files+=("$file")
    fi
  done
  
  if [ ${#missing_files[@]} -gt 0 ]; then
    echo "::error::Required files missing:"
    for file in "${missing_files[@]}"; do
      echo "::error::  - $file"
    done
    exit 1
  fi
}

# 执行前置检查
check_prerequisites

SESSION_HOOK=(bash hooks-handlers/session-start.sh)
PASS=0
FAIL=0

pass() {
  echo "  PASS  $1"
  PASS=$((PASS + 1))
}

fail() {
  # GitHub Actions 特殊指令：在 UI 中以红色标注错误
  if [ -n "$GITHUB_ACTIONS" ]; then
    echo "::error::FAIL: $1"
  else
    echo "  FAIL  $1"
  fi
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
echo "=== Manifest 字段完整性校验 ==="

manifest_check_file=$(mktemp)
python3 - > "$manifest_check_file" 2>&1 <<'PYEOF'
import json, sys
from pathlib import Path

errors = []

plugin = json.loads(Path(".claude-plugin/plugin.json").read_text())
marketplace = json.loads(Path(".claude-plugin/marketplace.json").read_text())

for field in ["name", "version", "description"]:
    if not plugin.get(field):
        errors.append(f"plugin.json missing or empty: {field}")
if not plugin.get("author", {}).get("name"):
    errors.append("plugin.json missing author.name")

if not marketplace.get("name"):
    errors.append("marketplace.json missing name")
if not marketplace.get("plugins"):
    errors.append("marketplace.json has no plugins")
else:
    mp_plugin = marketplace["plugins"][0]
    for field in ["name", "version", "description"]:
        if not mp_plugin.get(field):
            errors.append(f"marketplace.json plugin missing or empty: {field}")
    if not mp_plugin.get("author", {}).get("name"):
        errors.append("marketplace.json plugin missing author.name")

if errors:
    for e in errors:
        print(e)
    sys.exit(1)
PYEOF

manifest_exit=$?
if [ $manifest_exit -eq 0 ]; then
  pass "plugin.json required fields"
  pass "marketplace.json required fields"
else
  fail "plugin.json required fields"
  fail "marketplace.json required fields ($(cat "$manifest_check_file"))"
fi
rm -f "$manifest_check_file"

echo ""
echo "=== additionalContext 长度校验 ==="

context_len=$(printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ctx = data.get('hookSpecificOutput', {}).get('additionalContext', '')
print(len(ctx))
" 2>/dev/null)

# additionalContext 应该非空且不超过 2000 字符
if [ -n "$context_len" ] && [ "$context_len" -gt 0 ] && [ "$context_len" -le 2000 ]; then
  pass "additionalContext length is valid: 0 < $context_len <= 2000"
else
  fail "additionalContext length invalid (got: $context_len, expected: 0 < length <= 2000)"
fi

echo ""
echo "=== JSON 结构层级校验 ==="

# 检查 hookEventName
if printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
out = data['hookSpecificOutput']
assert out.get('hookEventName') == 'SessionStart'
" 2>/dev/null; then
  pass "hookSpecificOutput.hookEventName == SessionStart"
else
  fail "hookSpecificOutput.hookEventName missing or not 'SessionStart'"
fi

# 检查 additionalContext key
if printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
out = data['hookSpecificOutput']
assert 'additionalContext' in out
" 2>/dev/null; then
  pass "hookSpecificOutput.additionalContext key present"
else
  fail "hookSpecificOutput.additionalContext key missing"
fi


echo ""
echo "=== 跳过规则关键词检查 ==="

for skip_cmd in "ls" "cd" "cat" "pwd" "git status"; do
  if grep -q "$skip_cmd" <<<"$result"; then
    pass "skip rule contains: $skip_cmd"
  else
    fail "skip rule missing: $skip_cmd"
  fi
done

echo ""
echo "=== 解释格式规则关键词检查 ==="

for rule_kw in "commas" "risks or side effects"; do
  if grep -q "$rule_kw" <<<"$result"; then
    pass "format rule contains: $rule_kw"
  else
    fail "format rule missing: $rule_kw"
  fi
done

echo ""
echo "=== hook 幂等性 ==="

result2=$("${SESSION_HOOK[@]}" 2>/dev/null)
if [ "$result" = "$result2" ]; then
  pass "hook output is idempotent"
else
  fail "hook output differs between runs"
fi

echo ""
echo "=== stderr 干净 ==="

stderr_output=$("${SESSION_HOOK[@]}" 2>&1 1>/dev/null)
if [ -z "$stderr_output" ]; then
  pass "hook produces no stderr output"
else
  fail "hook wrote to stderr: $stderr_output"
fi

echo ""
echo "=== manifest 版本号 semver 格式校验 ==="

if python3 -c "
import json, re
from pathlib import Path

plugin = json.loads(Path('.claude-plugin/plugin.json').read_text())
version = plugin.get('version', '')
assert re.fullmatch(r'\d+\.\d+\.\d+', version), f'version {version!r} is not semver'
" 2>/dev/null; then
  pass "plugin version is valid semver"
else
  fail "plugin version is not valid semver"
fi

echo ""
echo "=== marketplace.json category 字段校验 ==="

if python3 -c "
import json
from pathlib import Path

marketplace = json.loads(Path('.claude-plugin/marketplace.json').read_text())
plugin = marketplace['plugins'][0]
assert plugin.get('category'), 'category field missing or empty'
" 2>/dev/null; then
  pass "marketplace.json plugin has non-empty category"
else
  fail "marketplace.json plugin missing or empty category"
fi

echo ""
echo "=== A: JSON 原始输出不含破坏结构的裸换行（在字符串值内部） ==="

# Claude Code hook 协议接受多行 JSON，但 JSON 字符串值内不能有裸换行（会破坏解析）
# 验证方式：用 python json 模块解析，能解析即说明换行符均已正确转义
if printf '%s' "$result" | python3 -c "
import sys, json
raw = sys.stdin.read()
data = json.loads(raw)  # 若含裸换行会抛 JSONDecodeError
ctx = data['hookSpecificOutput']['additionalContext']
assert isinstance(ctx, str) and len(ctx) > 0
" 2>/dev/null; then
  pass "JSON output parses cleanly, no unescaped newlines in string values"
else
  fail "JSON output contains unescaped newlines that break parsing"
fi


echo ""
echo "=== plugin name 与 marketplace plugin name 一致 ==="

if python3 -c "
import json
from pathlib import Path
plugin = json.loads(Path('.claude-plugin/plugin.json').read_text())
marketplace = json.loads(Path('.claude-plugin/marketplace.json').read_text())
assert plugin['name'] == marketplace['plugins'][0]['name'], \
    f'plugin.json name={plugin[\"name\"]!r} != marketplace name={marketplace[\"plugins\"][0][\"name\"]!r}'
" 2>/dev/null; then
  pass "plugin.json name matches marketplace.json plugin name"
else
  fail "plugin.json name does not match marketplace.json plugin name"
fi

echo ""
echo "=== hooks.json command 使用 CLAUDE_PLUGIN_ROOT 变量 ==="

if python3 -c "
import json
from pathlib import Path
data = json.loads(Path('hooks/hooks.json').read_text())
cmd = data['hooks']['SessionStart'][0]['hooks'][0]['command']
assert '\${CLAUDE_PLUGIN_ROOT}' in cmd, f'command does not use CLAUDE_PLUGIN_ROOT: {cmd!r}'
" 2>/dev/null; then
  pass "hooks.json command uses \${CLAUDE_PLUGIN_ROOT}"
else
  fail "hooks.json command does not use \${CLAUDE_PLUGIN_ROOT}"
fi

echo ""
echo "=== additionalContext 包含 😇 格式说明 ==="

if printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ctx = data['hookSpecificOutput']['additionalContext']
assert '😇 your explanation here' in ctx, 'format instruction missing from additionalContext'
" 2>/dev/null; then
  pass "additionalContext contains '😇 your explanation here' format instruction"
else
  fail "additionalContext missing '😇 your explanation here' format instruction"
fi

echo ""
echo "=== 结果 ==="
echo "  通过: $PASS  失败: $FAIL"
echo ""

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

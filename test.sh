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
echo "=== JSON 转义边界测试 ==="

# 所有转义验证均通过真实运行 session-start.sh 的输出来验证，不复制其内部逻辑

# 验证 hook 输出的 JSON 可被解析（隐含验证了双引号、反斜杠、换行符等均已正确转义）
if python3 -c "
import subprocess, json
result = subprocess.run(['bash', 'hooks-handlers/session-start.sh'], capture_output=True, text=True)
data = json.loads(result.stdout)
ctx = data['hookSpecificOutput']['additionalContext']
assert isinstance(ctx, str) and len(ctx) > 0
" 2>/dev/null; then
  pass "json_escape: hook output is valid JSON (all special chars escaped)"
else
  fail "json_escape: hook output is not valid JSON"
fi

# 验证 additionalContext 字符串值中包含双引号内容（prompt 里有 \"😇 your explanation here\"）
# 若双引号转义有问题，JSON 解析会失败，上面已覆盖；这里额外验证解析后内容完整性
if python3 -c "
import subprocess, json
result = subprocess.run(['bash', 'hooks-handlers/session-start.sh'], capture_output=True, text=True)
data = json.loads(result.stdout)
ctx = data['hookSpecificOutput']['additionalContext']
# prompt 中含有换行符（段落分隔），验证解析后换行符被正确还原为 Python 字符串中的 \n
assert '\n' in ctx, 'expected newlines in additionalContext after JSON decode'
" 2>/dev/null; then
  pass "json_escape: newlines correctly round-tripped through JSON encode/decode"
else
  fail "json_escape: newlines not correctly handled"
fi

echo ""
echo "=== Manifest 字段完整性校验 ==="

python3 - > /tmp/cc_buddy_manifest_check.txt 2>&1 <<'PYEOF'
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
  fail "manifest required fields check ($(cat /tmp/cc_buddy_manifest_check.txt))"
fi
rm -f /tmp/cc_buddy_manifest_check.txt

echo ""
echo "=== additionalContext 长度检查 ==="

context_len=$(printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ctx = data.get('hookSpecificOutput', {}).get('additionalContext', '')
print(len(ctx))
" 2>/dev/null)

# additionalContext 不应超过 2000 字符，避免 token 浪费
if [ -n "$context_len" ] && [ "$context_len" -le 2000 ]; then
  pass "additionalContext length <= 2000 chars (got: $context_len)"
else
  fail "additionalContext too long or unreadable (got: $context_len)"
fi

echo ""
echo "=== JSON 结构层级校验 ==="

if python3 -c "
import subprocess, json, sys
result = subprocess.run(['bash', 'hooks-handlers/session-start.sh'], capture_output=True, text=True)
data = json.loads(result.stdout)
out = data['hookSpecificOutput']
assert out.get('hookEventName') == 'SessionStart', f'hookEventName is {out.get(\"hookEventName\")!r}'
assert 'additionalContext' in out, 'additionalContext key missing'
" 2>/dev/null; then
  pass "hookSpecificOutput.hookEventName == SessionStart"
  pass "hookSpecificOutput.additionalContext key present"
else
  fail "JSON structure: hookEventName or additionalContext missing/wrong"
fi

echo ""
echo "=== additionalContext 非空校验 ==="

context_nonempty=$(printf '%s' "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ctx = data.get('hookSpecificOutput', {}).get('additionalContext', '')
print(len(ctx))
" 2>/dev/null)

if [ -n "$context_nonempty" ] && [ "$context_nonempty" -gt 0 ]; then
  pass "additionalContext is non-empty (got: $context_nonempty chars)"
else
  fail "additionalContext is empty or unreadable"
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
echo "=== additionalContext 字符串值内换行符已正确转义 ==="

# 在 JSON 原始文本中，字符串值内的换行必须表示为 \n（两个字符），不能是裸 0x0A
# 提取 additionalContext 的原始 JSON 字符串部分，检查其中不含裸 0x0A
if python3 -c "
import subprocess, json
result = subprocess.run(['bash', 'hooks-handlers/session-start.sh'], capture_output=True, text=True)
raw = result.stdout
# 找到 additionalContext 的值在原始 JSON 文本中的位置，验证其中无裸换行
# 方法：将原始输出中 additionalContext 的 JSON 字符串值提取出来检查
data = json.loads(raw)
ctx_value = data['hookSpecificOutput']['additionalContext']
# json.dumps 会把 Python 字符串里的 \n 转义为 \\n
# 反过来：如果原始 JSON 里有裸换行，json.loads 会失败（上面已验证）
# 这里额外验证：重新序列化后能还原，证明转义是双向一致的
re_encoded = json.dumps(ctx_value)
re_decoded = json.loads(re_encoded)
assert re_decoded == ctx_value, 'round-trip encode/decode mismatch'
" 2>/dev/null; then
  pass "additionalContext newlines are properly escaped (round-trip verified)"
else
  fail "additionalContext escape round-trip failed"
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

if python3 -c "
import subprocess, json
result = subprocess.run(['bash', 'hooks-handlers/session-start.sh'], capture_output=True, text=True)
data = json.loads(result.stdout)
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

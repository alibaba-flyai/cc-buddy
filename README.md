<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/2n/centaur.svg" width="106" alt="cc-teacher" />
  <h1>cc-teacher</h1>
  <p><em>Make every line of your cc building more fun and enlightening, explains unfamiliar commands before Claude Code executes them,</em></p>
</div>

<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/o5/cc.gif" width="800" alt="cc-teacher demo" />
</div>

## Overview

cc-teacher adds lightweight guidance to Claude Code at the moment an operation is about to run. It is meant for cases where the tool call is valid, but the user may not immediately understand what it does or why it matters.

It runs as a `PreToolUse` hook, explains non-trivial operations in one short line, then lets execution continue. The same `(tool, operation)` pair is only explained once per session. Typical cases include Docker, CI workflows, Next.js files, Prisma commands, `.env` files, package installation, and riskier shell commands such as `sudo`, `rm -rf`, or `git push --force`. Trivially obvious operations like `ls`, `cat`, and `git status` are skipped without an LLM call.

## Installation

In a fresh Claude Code CLI session:

```text
/plugin marketplace add alibaba-flyai/cc-teacher
/plugin install cc-teacher@flyai
/reload-plugins
```

## Examples

In a fresh Claude Code CLI session, inside a project that does not already have `axios`:

```text
请直接执行 npm install axios
```

`cc-teacher` may show:

```text
☻ 安装 axios，一个基于 Promise 的 HTTP 客户端，用于浏览器和 Node.js 发起网络请求
  https://axios-http.com
```

## How It Works

```text
Claude runs a tool
       │
  PreToolUse hook
  checks exemption list
       │
  ┌────┴─────┐
  │          │
exempt    everything else
  │          │
exit 0     call LLM
(skip)         │
           ┌───┴────┐
           │        │
        trivial   explanation
        (empty)     │
           │     warning card
        exit 0      │
        (skip)   exit 0 (allow)
```

Once a `(tool, operation)` pair has been explained in a session, cc-teacher exits 0 on subsequent runs and does not interrupt again.

## Uninstall

```text
/plugin uninstall cc-teacher@flyai
/plugin marketplace remove flyai
/reload-plugins
```

## Development

```bash
git clone https://github.com/alibaba-flyai/cc-teacher.git
cd cc-teacher
claude --plugin-dir .
```

`claude --plugin-dir .` loads the plugin from the current directory for the current Claude Code session only. It is for local development and debugging, not global installation.

Main files:

```text
.claude-plugin/plugin.json      plugin manifest
.claude-plugin/marketplace.json marketplace manifest
knowledge/classifier.py         exemption list
hooks-handlers/pre-tool-use.py  hook runtime
hooks/hooks.json                hook declaration
```

If cc-teacher explains something too obvious, add a pattern to `SIMPLE_BASH_PATTERNS` in `knowledge/classifier.py` and verify it:

```bash
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('my-command --flag'))"
# expect: None
```

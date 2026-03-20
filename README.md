<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/2n/centaur.svg" width="106" alt="cc-teacher" />
  <h1>cc-teacher</h1>
  <p><em>Explains unfamiliar operations before Claude Code executes them.</em></p>
</div>

<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/o5/cc.gif" width="800" alt="cc-teacher demo" />
</div>

Explains unfamiliar operations before Claude Code executes them.

## Overview

Everyone has a blind spot. An engineer unfamiliar with Next.js copying a component, a backend developer touching a CI workflow, a frontend developer running their first database migration. Claude Code moves fast, but not everyone knows what just ran.

cc-teacher adds a PreToolUse hook to Claude Code. Before each tool call, it checks whether the operation is worth explaining. If so, it delivers a one-line plain-language note and lets the tool proceed immediately. The same operation is only explained once per session.

What gets explained: Dockerfile, `docker-compose.yml`, GitHub Actions workflows, Next.js components, Prisma schema, `.env` files, `docker compose up`, `npm install`, `npx prisma migrate`, `sudo`, `rm -rf`, `git push --force`, and similar. Trivially obvious operations (`ls`, `cat`, `git status`) are skipped without an LLM call.

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

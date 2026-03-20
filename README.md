<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/2n/centaur.svg" width="106" alt="cc-teacher" />
  <h1>cc-teacher</h1>
  <p><em>Explains unfamiliar operations before Claude Code executes them.</em></p>
</div>

<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/o5/cc.gif" width="800" alt="cc-teacher demo" />
</div>

`cc-teacher` adds a `PreToolUse` hook to Claude Code. Before a tool call runs, it decides whether the operation is worth explaining. If yes, it prints a short plain-language note and then lets the tool continue. The same operation is explained only once per session.

Typical examples:
- Dockerfile, `docker-compose.yml`, GitHub Actions workflows
- Next.js components, Prisma schema, `.env` files
- `docker compose up`, `npm install`, `npx prisma migrate`
- `sudo`, `rm -rf`, `git push --force`

Obvious operations like `ls`, `cat`, and `git status` are skipped without an LLM call.

## Installation

In Claude Code CLI:

```text
/plugin marketplace add alibaba-flyai/cc-teacher
/plugin install cc-teacher@flyai
/reload-plugins
```

## Examples

In Claude Code CLI:

```text
帮我安装一个好用的请求库
```

If Claude chooses `axios`, `cc-teacher` may show:

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

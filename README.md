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

In Claude Code:

```text
/plugin marketplace add alibaba-flyai/cc-teacher
/plugin install cc-teacher@flyai
/reload-plugins
```

Or open `/plugin` and install it from the marketplace UI.

## Examples

Claude runs `npx prisma migrate dev`:

```text
☻ Compares schema.prisma against the current database state, generates and runs a migration,
  and updates Prisma Client types. Use prisma migrate deploy in production.
  https://www.prisma.io/docs/orm/prisma-migrate
```

Claude edits a `.tsx` file containing `use client`:

```text
☻ 这是一个 Next.js 客户端组件，会在浏览器中执行，适合处理状态和交互，数据获取和敏感
  逻辑应保留在 Server Component 或 Route Handler 中
```

`cc-teacher` warns, it does not block.

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

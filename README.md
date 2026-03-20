# cc-teacher

Explains unfamiliar operations before Claude Code executes them.

## Why

Everyone has a blind spot. An engineer unfamiliar with Next.js copying a component, a backend developer touching a CI workflow, a frontend developer running their first database migration. Claude Code moves fast, but not everyone knows what just ran.

cc-teacher adds a PreToolUse hook to Claude Code. Before each tool call, it checks whether the operation is worth explaining. If so, it delivers a one-line plain-language note and lets the tool proceed immediately. The same operation is only explained once per session.

What gets explained: Dockerfile, docker-compose.yml, GitHub Actions workflows, Next.js components, Prisma schema, `.env` files, `docker compose up`, `npm install`, `npx prisma migrate`, `sudo`, `rm -rf`, `git push --force`, and similar. Trivially obvious operations (`ls`, `cat`, `git status`) are skipped without an LLM call.

## Installation

Requires Claude Code `1.0.33` or later.

In Claude Code:

```text
/plugin marketplace add alibaba-flyai/cc-teacher
/plugin install cc-teacher@alibaba-flyai-cc-teacher
/reload-plugins
```

This installs `cc-teacher` from the repository's GitHub marketplace manifest in `.claude-plugin/marketplace.json`.

For local development from a clone:

```bash
claude --plugin-dir .
```

`--plugin-dir .` means "load a plugin from the current directory for this Claude Code session only". It is useful for local development and debugging because changes in the repo are picked up immediately, but it does not install the plugin globally.

## Examples

**Claude runs `npx prisma migrate dev`:**

```
☻ Compares schema.prisma against the current database state, generates and runs a migration,
  and updates Prisma Client types. Use prisma migrate deploy in production.
  https://www.prisma.io/docs/orm/prisma-migrate
```

**Claude edits a `.tsx` file containing `use client`:**

```
☻ 这是一个 Next.js 客户端组件，会在浏览器中执行，适合处理状态和交互，数据获取和敏感
  逻辑应保留在 Server Component 或 Route Handler 中
```

The tool call continues immediately. cc-teacher warns, it does not block.

## How it works

```
Claude runs a tool
       │
  PreToolUse hook
  checks exemption list
       │
  ┌────┴─────┐
  │          │
exempt    everything else
  │          │
exit 0    call LLM (kimi-k2.5)
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
/plugin uninstall cc-teacher@alibaba-flyai-cc-teacher
/plugin marketplace remove alibaba-flyai-cc-teacher
/reload-plugins
```

## Contributing

Clone from GitHub and run the plugin directly from the repository:

```bash
git clone https://github.com/alibaba-flyai/cc-teacher.git
cd cc-teacher
claude --plugin-dir .
```

### Project layout

```
cc-teacher/
├── .claude-plugin/
│   ├── marketplace.json     # GitHub marketplace catalog for this repository
│   └── plugin.json          # plugin metadata
├── knowledge/
│   └── classifier.py        # all pattern rules, the only file you normally edit
├── hooks-handlers/
│   └── pre-tool-use.py      # hook runtime: classify, call LLM, output warning, allow
├── hooks/
│   └── hooks.json           # hook declarations
└── CLAUDE.md                # contributor guidance for assistants working in this repo
```

The following files are contributor tooling, not part of the installed plugin. They configure the AI assistant used when developing this project:

```
├── .claude/
    ├── rules/
    │   ├── classifier.md    # required fields and doc URL policy for new rules
    │   └── python.md        # Python conventions and verification commands
    └── skills/
        └── add-classifier-rule/SKILL.md   # /add-classifier-rule slash command
```

### Tuning the exemption list

The LLM decides what to explain. The only manual configuration is `SIMPLE_BASH_PATTERNS` and `SIMPLE_FILE_NAMES`/`SIMPLE_FILE_EXTENSIONS` in `knowledge/classifier.py`, operations that match these are skipped entirely without an LLM call.

If cc-teacher is explaining something too obvious, add a pattern to `SIMPLE_BASH_PATTERNS`:

```python
r"^my-command(\s|$)",
```

Verify the exemption works:

```bash
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('my-command --flag'))"
# expect: None
```

### Distribution

This repository is distributed directly from GitHub through `.claude-plugin/marketplace.json`. If you install from a local clone with `claude --plugin-dir .`, changes to `knowledge/classifier.py` and `hooks-handlers/pre-tool-use.py` are picked up immediately in the next Claude Code session.

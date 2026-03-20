<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/2n/centaur.svg" width="106" alt="cc-teacher" />
  <h1>cc-teacher</h1>
  <p><em>Explains unfamiliar operations before Claude Code executes them.</em></p>
</div>

<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/60/cc.gif" width="800" alt="cc-teacher demo" />
</div>

## Why

Everyone has a blind spot. An engineer unfamiliar with Next.js copying a component, a backend developer touching a CI workflow, a frontend developer running their first database migration. Claude Code moves fast, but not everyone knows what just ran.

cc-teacher adds a PreToolUse hook to Claude Code. Before each tool call, it checks whether the operation is worth explaining. If so, it delivers a one-line plain-language note and lets the tool proceed immediately. The same operation is only explained once per session.

What gets explained: Dockerfile, docker-compose.yml, GitHub Actions workflows, Next.js components, Prisma schema, `.env` files, `docker compose up`, `npm install`, `npx prisma migrate`, `sudo`, `rm -rf`, `git push --force`, and similar. Trivially obvious operations (`ls`, `cat`, `git status`) are skipped without an LLM call.

## Installation

```bash
curl -fsSL https://claude.io.alibaba-inc.com/install.sh | bash
```

Registers hooks in `~/.claude/settings.json`. A built-in API key is included for initial use.

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

```bash
curl -fsSL https://claude.io.alibaba-inc.com/uninstall.sh | bash
```

## Contributing

### Internal contributor setup

Before contributing from Alibaba internal network, complete the following setup:

1. Configure your access key at [code.alibaba-inc.com/profile/keys](https://code.alibaba-inc.com/profile/keys)
2. Generate an SSH key by following [the internal guide](https://aliyuque.antfin.com/alicode/docs/agoow0?spm=defwork..0.0.456722c1DiwJ7f#afRjq), or run:

```bash
ssh-keygen -t rsa -C "your-company-email"
```

3. Print your public key and copy it:

```bash
cat ~/.ssh/id_rsa.pub
```

4. Add that public key at [code.alibaba-inc.com/profile/keys](https://code.alibaba-inc.com/profile/keys)
5. Configure your Git identity:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-company-email"
```

6. Clone the repository:

```bash
git clone git@gitlab.alibaba-inc.com:fliggy-claude/cc-teacher.git
cd cc-teacher
claude
```

### Project layout

```
cc-teacher/
├── knowledge/
│   └── classifier.py        # all pattern rules, the only file you normally edit
├── hooks-handlers/
│   └── pre-tool-use.py      # hook runtime: classify, call LLM, output warning, allow
├── hooks/
│   └── hooks.json           # hook declarations
├── .aoneci/
│   └── deploy-pages.yaml    # Aone Pages CI config
├── install.sh               # registers hooks in ~/.claude/settings.json
└── uninstall.sh             # removes hooks from ~/.claude/settings.json
```

The following files are contributor tooling, not part of the installed plugin. They configure the AI assistant used when developing this project:

```
├── CLAUDE.md                # project rules for Claude Code (language, conventions, file map)
└── .claude/
    ├── rules/
    │   ├── classifier.md    # required fields and doc URL policy for new rules
    │   └── python.md        # Python conventions and verification commands
    └── skills/
        └── add-classifier-rule/SKILL.md   # /add-classifier-rule slash command
```

### Tuning the exemption list

The LLM decides what to explain. The only manual configuration is `SIMPLE_BASH_PATTERNS` and `SIMPLE_FILE_NAMES`/`SIMPLE_FILE_EXTENSIONS` in `knowledge/classifier.py` — operations that match these are skipped entirely without an LLM call.

If cc-teacher is explaining something too obvious, add a pattern to `SIMPLE_BASH_PATTERNS`:

```python
r"^my-command(\s|$)",
```

Verify the exemption works:

```bash
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('my-command --flag'))"
# expect: None
```

### Deployment

`install.sh` is served via [Aone Pages](https://pages.alibaba-inc.com/docs/intro) static hosting. The config lives in `.aoneci/deploy-pages.yaml`: no build step, repo root served directly. Pushing to `main` triggers an automatic deployment, so the script at `https://claude.io.alibaba-inc.com/install.sh` is always in sync with the latest commit.

Changes to the exemption list in `knowledge/classifier.py` are picked up automatically on next tool call if installed from a local clone. For curl-based installs, users need to re-run `install.sh` to pull the updated files.

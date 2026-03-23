<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/2n/centaur.svg" width="106" alt="cc-buddy" />
  <h1>cc-buddy 😇</h1>
  <p><em>Make every line of your cc building more fun and enlightening, by commenting codes real-time before Claude Code executes them.</em></p>
</div>

<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/o5/cc.gif" width="800" alt="cc-buddy demo" />
</div>

## Overview

cc-buddy 😇 adds lightweight guidance to Claude Code (cc) at the moment an operation is about to run. It is meant for cases where the tool call is valid, but the builder may not immediately understand what it does or why it matters.

It runs as a `SessionStart` hook that injects a single `additionalContext` instruction at session start. Claude then explains each Bash command, Edit, Write, or MultiEdit operation in its own output before executing it. No external LLM is needed; Claude itself generates the explanations. Trivially obvious commands like `ls`, `cat`, and `git status` are skipped automatically.

## Installation

```bash
claude plugins marketplace add alibaba-flyai/cc-buddy
claude plugins install cc-buddy@flyai
```

Then open a new cc tab or shell to activate.

## Examples

**Bash**: explain before running a command

    > 帮我安装 axios

    😇 安装 axios，一个基于 Promise 的 HTTP 客户端，支持拦截器和自动 JSON 转换

    $ npm install axios

**Edit**: explain before showing the diff

    > Remove the avatar border radius

    😇 Remove border radius from avatar, switch to sharp corners to match the design language

    src/components/Avatar.tsx
    66 -     "borderRadius": 45,
    66 +     "borderRadius": 0,

## How It Works

```
┌───────────┐     ┌──────────────────┐     ┌──────────────────────┐
│  Session  │────▶│ session-start.sh │────▶│  additionalContext   │
│  starts   │     │ hook fires       │     │  injected into Claude│
└───────────┘     └──────────────────┘     └──────────┬───────────┘
                                                      │
                                                      ▼
                                           ┌──────────────────────┐
                                           │ Before Bash / Edit:  │
                                           │ 😇 explain, then run  │
                                           │                      │
                                           │ Before ls / cd:      │
                                           │ skip, run directly   │
                                           └──────────────────────┘
```

## Update

```bash
claude plugins marketplace update flyai
claude plugins update cc-buddy@flyai
```

Then open a new cc tab or shell to apply the update.

## Uninstall

```bash
claude plugins uninstall cc-buddy@flyai
claude plugins marketplace remove flyai
```

Then open a new cc tab or shell window.

## Development

```bash
git clone https://github.com/alibaba-flyai/cc-buddy.git
cd cc-buddy
```

To test changes, open a separate project (not cc-buddy itself) and pass the cloned directory:

```bash
git clone https://github.com/alibaba-flyai/cc-buddy.git
cd ~/your-other-project
claude --plugin-dir /path/to/cloned/cc-buddy
```

The `--plugin-dir` flag loads the plugin for this session only, without installing it globally. You must use a different project because the checked-in `.claude/settings.json` disables plugins inside cc-buddy to prevent self-explanation loops during development.

Main files:

```text
.claude-plugin/plugin.json           plugin manifest
.claude-plugin/marketplace.json      marketplace manifest
hooks-handlers/session-start.sh      SessionStart hook (injects explanation instructions)
hooks/hooks.json                     hook declarations
```

Run the test suite locally without installing the plugin:

```bash
bash test.sh
```

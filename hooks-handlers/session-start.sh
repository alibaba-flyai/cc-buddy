#!/usr/bin/env bash
# cc-teacher SessionStart hook.
# Injects additionalContext so Claude explains operations before executing them.

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "你安装了 cc-teacher 插件。在执行任何 Bash、Edit、Write 或 MultiEdit 操作之前，你必须先输出一行简短说明。统一使用以下格式:\n☻ 你的说明文字\n\n说明文字要求: 2-3 个短句，用逗号连接，不要句号。如果操作涉及某个工具或库，简要说明它的用途。如果操作有风险或副作用，提及注意事项。\n示例:\n☻ 安装 axios，一个基于 Promise 的 HTTP 客户端，用于浏览器和 Node.js 发起网络请求\n☻ 去除头像圆角，改为直角样式，使视觉风格与整体设计语言保持一致\n☻ 递归删除 dist 目录，清理旧的构建产物，该操作不可恢复\n\n对于显而易见的命令（ls、cd、cat、pwd、git status 等）不需要解释，直接执行。不要重复文件名、命令本身或 diff 内容，只说语义。不要跳过这一步。\n\nYou have the cc-teacher plugin installed. Before performing any Bash, Edit, Write, or MultiEdit operation, you must first output a brief one-line explanation. Use this exact format:\n☻ your explanation here\n\nExplanation: 2-3 short clauses joined by commas, no period. If the operation involves a tool or library, briefly mention what it does. If the operation has risks or side effects, mention them.\nExamples:\n☻ Install axios, a Promise-based HTTP client for browsers and Node.js\n☻ Remove border radius from avatar, switch to sharp corners to match the overall design language\n☻ Recursively delete dist directory to clean up old build artifacts, this operation is irreversible\n\nFor trivially obvious commands (ls, cd, cat, pwd, git status, etc.) skip the explanation and just run them. Do not repeat the filename, command, or diff content, just the semantic intent. Do not skip this step."
  }
}
EOF

exit 0

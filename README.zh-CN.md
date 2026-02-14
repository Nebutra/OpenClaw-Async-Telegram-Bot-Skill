# OpenClaw 异步 Telegram Bot Skill

[![License: MIT](https://img.shields.io/badge/license-MIT-16a34a.svg)](./LICENSE)
[![Skill](https://img.shields.io/badge/skill-openclaw--async--telegram--bot-2563eb.svg)](./SKILL.md)
[![Smithery 收录](https://img.shields.io/badge/Smithery-Discover-111827.svg)](https://smithery.ai/skills/nebutra/openclaw-async-telegram-bot-skill)

[English](./README.md) | 简体中文

把一个 OpenClaw，快速扩展成可并行运行的 Telegram Bot 矩阵。

这个 Skill 用一套可重复 SOP 自动完成机器人接入，并带安全护栏：
- 通过 Telegram `getMe` 校验 Bot Token
- 强制用户名规则 `Nebutra###_bot`
- 新建机器人默认要求 fresh token（不再静默复用旧 token）
- 按序号自动映射古希腊哲学家英文名
- 自动写入 OpenClaw Telegram 账号配置
- 自动重启网关并做健康检查
- 可选：为每个 Bot 创建独立 Agent，支持并行工作流

## 10 秒安装

```bash
npx skills add https://github.com/Nebutra/OpenClaw-Async-Telegram-Bot-Skill --skill openclaw-async-telegram-bot
```

发现页：
- Smithery: https://smithery.ai/skills/nebutra/openclaw-async-telegram-bot-skill
- Skills 目录: https://skills.sh/nebutra/openclaw-async-telegram-bot-skill/openclaw-async-telegram-bot

## 快速开始

```bash
# 1) 自动生成 BotFather 新建计划（名称 + 用户名 + 下一序号）
bash scripts/prepare_botfather_new_bot.sh

# 2) 在 BotFather 按计划创建机器人并复制 fresh token

# 新增/更新一个 Telegram Bot 账号
bash scripts/add_async_telegram_bot.sh --token "<BOTFATHER_TOKEN>"

# 新增 Bot 并创建绑定该账号的独立 Agent
bash scripts/add_async_telegram_bot.sh --token "<BOTFATHER_TOKEN>" --agent-id "plato-agent"
```

## 国内用户：OpenClaw + MiniMax 国内 API 一键配置

如果你使用的是 MiniMax 国内 API，可直接执行下面命令完成覆盖配置（`baseUrl`、`authHeader`、模型窗口、默认模型）：

```bash
export MINIMAX_API_KEY="你的 MiniMax Key"

bash -c '
set -euo pipefail
CFG="$HOME/.openclaw/openclaw.json"
[ -f "$CFG" ] || { echo "未找到 $CFG，请先运行 openclaw onboard"; exit 1; }
[ -n "${MINIMAX_API_KEY:-}" ] || { echo "请先设置 MINIMAX_API_KEY"; exit 1; }

TMP="$(mktemp)"
jq --arg key "$MINIMAX_API_KEY" \
  '"'"'.models.mode = "merge"
  | .models.providers.minimax.baseUrl = "https://api.minimaxi.com/anthropic"
  | .models.providers.minimax.api = "anthropic-messages"
  | .models.providers.minimax.authHeader = true
  | .models.providers.minimax.apiKey = $key
  | .models.providers.minimax.models = [
      {
        "id": "MiniMax-M2.5",
        "name": "MiniMax M2.5",
        "reasoning": false,
        "input": ["text"],
        "cost": { "input": 15, "output": 60, "cacheRead": 2, "cacheWrite": 10 },
        "contextWindow": 204800,
        "maxTokens": 8192
      }
    ]
  | .agents.defaults.model.primary = "minimax/MiniMax-M2.5"
  | .agents.defaults.models["minimax/MiniMax-M2.5"] = (.agents.defaults.models["minimax/MiniMax-M2.5"] // {})
  | .agents.defaults.contextTokens = 204800
  | .agents.defaults.thinkingDefault = "off"
  '"'"' "$CFG" > "$TMP"

mv "$TMP" "$CFG"
openclaw gateway restart
openclaw channels status --probe
'
```

完成后可用以下命令自检：

```bash
openclaw tui
```

预期状态：
- 模型显示 `minimax/MiniMax-M2.5`
- 上下文接近 `205k`（即 204800）
- `think` 默认关闭（`off`）

## MiniMax CodingPlan 邀请码

- 邀请码：`6jBWg7zvmE`
- 邀请链接（扫码同款，活动页）：https://platform.minimaxi.com/subscribe/coding-plan?code=6jBWg7zvmE&source=img

![MiniMax CodingPlan 邀请海报](./assets/minimax-codingplan-invite.png)

## 命令参考

```bash
# BotFather 规划助手
bash scripts/prepare_botfather_new_bot.sh

# 强制指定序号和名称
bash scripts/prepare_botfather_new_bot.sh --serial 2 --name "Aristotle"

# 输出 JSON（给自动化流程用）
bash scripts/prepare_botfather_new_bot.sh --json

# 指定 account id
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --account-id "plato-007"

# 指定显示名
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --name "Plato"

# 仅预演，不落地
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --dry-run

# 跳过网关重启
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --skip-restart

# 创建 Agent 时指定模型
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --agent-id "plato-agent" --model "MiniMax-M2.5"

# 明确允许复用已注册 token（仅用于更新场景）
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --allow-existing-token
```

## 安全约束

- 用户名必须匹配：`^Nebutra[0-9]{3}_bot$`
- Token 必须通过 Telegram API 校验
- 新建机器人必须使用 BotFather 生成的新 token
- 健康检查必须通过：`running=true` 且 `probe.ok=true`
- 自动防止 account-id 与已有 bot-id 冲突

## 仓库结构

- `SKILL.md`：Skill 触发规则与执行流程
- `scripts/prepare_botfather_new_bot.sh`：BotFather 新建流程规划助手
- `scripts/add_async_telegram_bot.sh`：生产可用的接入脚本

## 依赖

- `openclaw`
- `curl`
- `jq`

## 许可证

MIT

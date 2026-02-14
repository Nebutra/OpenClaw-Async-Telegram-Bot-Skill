# OpenClaw Async Telegram Bot Skill

[![License: MIT](https://img.shields.io/badge/license-MIT-16a34a.svg)](./LICENSE)
[![Skill](https://img.shields.io/badge/skill-openclaw--async--telegram--bot-2563eb.svg)](./SKILL.md)
[![Discover on Smithery](https://img.shields.io/badge/Smithery-Discover-111827.svg)](https://smithery.ai/skills/nebutra/openclaw-async-telegram-bot-skill)

English | [简体中文](./README.zh-CN.md)

Scale one OpenClaw into a multi-bot Telegram fleet in minutes.

This skill automates Telegram bot onboarding with guardrails:
- validates tokens with Telegram `getMe`
- enforces username policy `Nebutra###_bot`
- requires fresh token for new-bot flow (no silent reuse of old tokens)
- auto-maps bot naming to Greek philosopher identities
- wires bots into OpenClaw accounts
- restarts and health-checks gateway automatically
- can spawn one isolated agent per bot for parallel workflows

## Install in 10 Seconds

```bash
npx skills add https://github.com/Nebutra/OpenClaw-Async-Telegram-Bot-Skill --skill openclaw-async-telegram-bot
```

Alternative discovery pages:
- Smithery: https://smithery.ai/skills/nebutra/openclaw-async-telegram-bot-skill
- Skills directory: https://skills.sh/nebutra/openclaw-async-telegram-bot-skill/openclaw-async-telegram-bot

## Quick Start

```bash
# add/update one Telegram bot account
bash scripts/add_async_telegram_bot.sh --token "<BOTFATHER_TOKEN>"

# add bot + create isolated agent bound to this account
bash scripts/add_async_telegram_bot.sh --token "<BOTFATHER_TOKEN>" --agent-id "plato-agent"
```

## Command Reference

```bash
# force account id
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --account-id "plato-007"

# force display name
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --name "Plato"

# dry run only
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --dry-run

# skip gateway restart
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --skip-restart

# use a different model when creating agent
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --agent-id "plato-agent" --model "MiniMax-M2.5"

# intentionally reuse a token already registered in OpenClaw (update flow only)
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --allow-existing-token
```

## Safety and Policy

- Username must match: `^Nebutra[0-9]{3}_bot$`
- Token must pass Telegram API validation
- New bot flow must use a fresh BotFather token
- Health checks must pass: `running=true` and `probe.ok=true`
- Prevents account-id collisions with existing bot IDs

## Repository Layout

- `SKILL.md` - trigger rules + workflow for agent execution
- `scripts/add_async_telegram_bot.sh` - production onboarding script

## Requirements

- `openclaw`
- `curl`
- `jq`

## License

MIT

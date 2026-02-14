# OpenClaw Async Telegram Bot Skill

An OpenClaw skill that lets OpenClaw provision additional Telegram bot accounts for asynchronous/parallel operation.

## What It Does

- Validates a BotFather token via Telegram `getMe`
- Enforces username format: `Nebutra###_bot`
- Maps serial number to an English ancient Greek philosopher name
- Adds/updates OpenClaw Telegram account via `openclaw channels add`
- Restarts gateway and verifies `running=true` + `probe.ok=true`
- Optionally creates an isolated agent bound to the new Telegram account

## Install with skills CLI

```bash
npx skills add https://github.com/Nebutra/OpenClaw-Async-Telegram-Bot-Skill --skill openclaw-async-telegram-bot
```

## Skill Files

- `SKILL.md`
- `scripts/add_async_telegram_bot.sh`

## Usage

```bash
bash scripts/add_async_telegram_bot.sh --token "<BOTFATHER_TOKEN>"
```

Optional:

```bash
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --agent-id "socrates-agent"
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --account-id "plato-007"
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --dry-run
```

## Requirements

- `openclaw`
- `curl`
- `jq`

## License

MIT

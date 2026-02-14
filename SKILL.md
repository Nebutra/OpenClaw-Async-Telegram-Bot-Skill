---
name: openclaw-async-telegram-bot
description: Add or update asynchronous Telegram bot accounts in OpenClaw. Use when user asks to add multiple Telegram bots, run bots in parallel, or let OpenClaw self-provision Telegram bot accounts. Enforces username pattern Nebutra[three digits]_bot and philosopher-style English bot names.
---

# OpenClaw Async Telegram Bot

## Use This Skill When

- User asks for multiple Telegram bots in parallel ("异步机器人", "多开 bot", "parallel telegram bots")
- User asks OpenClaw to add a new Telegram bot token itself
- User wants one bot per account (optionally one bot per dedicated agent)

## Naming Rules

- Bot username must be `Nebutra[三位数字]_bot` (example: `Nebutra007_bot`)
- Bot display name must be an English ancient Greek philosopher name
- This skill uses this fixed set:
  - `Socrates`
  - `Plato`
  - `Aristotle`
  - `Pythagoras`
  - `Heraclitus`
  - `Democritus`
  - `Epicurus`
  - `Zeno`
  - `Thales`
  - `Anaxagoras`

## Workflow

1. Validate token with Telegram `getMe`.
2. Reject token if username does not match `^Nebutra[0-9]{3}_bot$`.
3. Select philosopher display name deterministically from the 3-digit serial in username.
4. Add/update Telegram account in OpenClaw (`channels add`).
5. Restart gateway and verify `running + probe.ok=true`.
6. Optional: create a dedicated isolated agent bound to `telegram:<accountId>`.

## Command

Run:

```bash
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>"
```

Optional flags:

```bash
# Force account id
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --account-id "plato-007"

# Force philosopher display name
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --name "Plato"

# Create isolated agent bound to this telegram account
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --agent-id "plato-agent"

# Dry run
bash scripts/add_async_telegram_bot.sh --token "<TOKEN>" --dry-run
```

## BotFather Notes

If username validation fails, stop and ask user to recreate bot in BotFather:

1. `/newbot`
2. Bot display name: philosopher English name
3. Bot username: `Nebutra###_bot`
4. Return the new token

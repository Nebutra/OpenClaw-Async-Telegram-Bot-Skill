#!/usr/bin/env bash
set -euo pipefail

NAME=""
SERIAL=""
PREFIX="Nebutra"
DIGITS=3
ACCOUNT_ID=""
AGENT_ID=""
MODEL_ID="MiniMax-M2.5"
TOKEN=""
NO_CONFIGURE=0
YES=0

usage() {
  cat <<'EOF'
Usage:
  botfather_rpa_assist_mac.sh [options]

Purpose:
  macOS-only RPA assistant for BotFather:
  1) plan next bot name/username
  2) open BotFather and send /newbot + name + username
  3) wait for fresh token
  4) configure OpenClaw automatically

Options:
  --name <display name>    Force bot display name (e.g. Aristotle)
  --serial <n>             Force serial for username
  --prefix <text>          Username prefix (default: Nebutra)
  --digits <n>             Serial digits width (default: 3)
  --account-id <id>        Force OpenClaw account id
  --agent-id <id>          Create isolated agent bound to this account
  --model <id>             Model id for optional agent creation
  --token <token>          Skip prompt and configure directly with token
  --no-configure           Only perform BotFather RPA; do not configure OpenClaw
  --yes                    Non-interactive confirmation for prompts
  -h, --help               Show help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: command not found: $1" >&2
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if (( YES == 1 )); then
    return 0
  fi
  local ans
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

mask_token() {
  local raw="$1"
  local len="${#raw}"
  if (( len <= 10 )); then
    printf '%s' "***"
    return
  fi
  printf '%s***%s' "${raw:0:6}" "${raw: -4}"
}

copy_and_send_line() {
  local line="$1"
  printf '%s' "$line" | pbcopy
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "v" using {command down}
  key code 36
end tell
APPLESCRIPT
}

can_send_keystrokes() {
  osascript <<'APPLESCRIPT' >/dev/null 2>&1
tell application "System Events"
  keystroke ""
end tell
APPLESCRIPT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --prefix)
      PREFIX="${2:-}"
      shift 2
      ;;
    --digits)
      DIGITS="${2:-}"
      shift 2
      ;;
    --account-id)
      ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --model)
      MODEL_ID="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --no-configure)
      NO_CONFIGURE=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this script only supports macOS (Darwin)." >&2
  exit 1
fi

need_cmd open
need_cmd osascript
need_cmd pbcopy
need_cmd pbpaste
need_cmd jq
need_cmd bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREP_SCRIPT="$SCRIPT_DIR/prepare_botfather_new_bot.sh"
ADD_SCRIPT="$SCRIPT_DIR/add_async_telegram_bot.sh"

if [[ ! -x "$PREP_SCRIPT" ]]; then
  echo "ERROR: missing executable: $PREP_SCRIPT" >&2
  exit 1
fi
if [[ ! -x "$ADD_SCRIPT" ]]; then
  echo "ERROR: missing executable: $ADD_SCRIPT" >&2
  exit 1
fi

prep_cmd=(bash "$PREP_SCRIPT" --json --prefix "$PREFIX" --digits "$DIGITS")
[[ -n "$SERIAL" ]] && prep_cmd+=(--serial "$SERIAL")
[[ -n "$NAME" ]] && prep_cmd+=(--name "$NAME")
[[ -n "$ACCOUNT_ID" ]] && prep_cmd+=(--account-id "$ACCOUNT_ID")
[[ -n "$AGENT_ID" ]] && prep_cmd+=(--agent-id "$AGENT_ID" --model "$MODEL_ID")

PLAN_JSON="$("${prep_cmd[@]}")"
DISPLAY_NAME="$(jq -r '.displayName' <<<"$PLAN_JSON")"
USERNAME="$(jq -r '.username' <<<"$PLAN_JSON")"
ACCOUNT_ID_FINAL="$(jq -r '.accountId' <<<"$PLAN_JSON")"

echo "RPA Plan"
echo "  display name: $DISPLAY_NAME"
echo "  username:     $USERNAME"
echo "  account id:   $ACCOUNT_ID_FINAL"

if ! confirm "Proceed to open BotFather and auto-send /newbot + name + username?"; then
  echo "Cancelled."
  exit 0
fi

OLD_CLIP="$(pbpaste 2>/dev/null || true)"
cleanup_clipboard() {
  printf '%s' "$OLD_CLIP" | pbcopy || true
}
trap cleanup_clipboard EXIT

open "tg://resolve?domain=BotFather" || true
sleep 1.0

osascript <<'APPLESCRIPT'
tell application "Telegram" to activate
APPLESCRIPT

if can_send_keystrokes; then
  if (( YES != 1 )); then
    echo "Focus BotFather chat in Telegram, then press Enter to continue."
    read -r _
  fi

  echo "Sending: /newbot"
  copy_and_send_line "/newbot"
  sleep 1.0

  echo "Sending display name: $DISPLAY_NAME"
  copy_and_send_line "$DISPLAY_NAME"
  sleep 1.0

  echo "Sending username: $USERNAME"
  copy_and_send_line "$USERNAME"
else
  echo "WARNING: macOS Accessibility permission is missing; cannot send keystrokes automatically."
  echo "Enable it in: System Settings -> Privacy & Security -> Accessibility"
  echo "Allow your terminal app (Terminal/iTerm/OpenClaw host app), then rerun."
  echo
  echo "Manual BotFather inputs:"
  echo "  /newbot"
  echo "  Name:     $DISPLAY_NAME"
  echo "  Username: $USERNAME"
  if (( NO_CONFIGURE == 1 )); then
    echo "RPA fallback finished (--no-configure)."
    exit 0
  fi
fi

if (( NO_CONFIGURE == 1 )); then
  echo "RPA step completed. No OpenClaw configuration requested (--no-configure)."
  exit 0
fi

if [[ -z "$TOKEN" ]]; then
  if (( YES == 1 )); then
    echo "ERROR: --yes mode requires --token unless --no-configure is used." >&2
    exit 1
  fi
  echo
  echo "BotFather should now return a fresh token."
  read -r -p "Paste fresh token here (leave empty to use clipboard): " TOKEN
  if [[ -z "$TOKEN" ]]; then
    TOKEN="$(pbpaste)"
  fi
fi

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: token is empty." >&2
  exit 1
fi
if [[ ! "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{20,}$ ]]; then
  echo "ERROR: token format looks invalid." >&2
  exit 1
fi

echo "Configuring OpenClaw with token: $(mask_token "$TOKEN")"

add_cmd=(bash "$ADD_SCRIPT" --token "$TOKEN" --name "$DISPLAY_NAME" --account-id "$ACCOUNT_ID_FINAL")
if [[ -n "$AGENT_ID" ]]; then
  add_cmd+=(--agent-id "$AGENT_ID" --model "$MODEL_ID")
fi

"${add_cmd[@]}"

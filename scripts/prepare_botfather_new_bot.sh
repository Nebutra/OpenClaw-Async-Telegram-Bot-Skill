#!/usr/bin/env bash
set -euo pipefail

PHILOSOPHERS=(
  "Socrates"
  "Plato"
  "Aristotle"
  "Pythagoras"
  "Heraclitus"
  "Democritus"
  "Epicurus"
  "Zeno"
  "Thales"
  "Anaxagoras"
)

PREFIX="Nebutra"
DIGITS=3
SERIAL=""
DISPLAY_NAME=""
ACCOUNT_ID=""
AGENT_ID=""
MODEL_ID="MiniMax-M2.5"
EMIT_JSON=0
CHECK_PUBLIC_USERNAME=1

usage() {
  cat <<'EOF'
Usage:
  prepare_botfather_new_bot.sh [options]

Options:
  --prefix <text>          Username prefix before serial (default: Nebutra)
  --digits <n>             Fixed serial width (default: 3)
  --serial <n>             Force serial instead of auto-select
  --name <display name>    Force display name (default: philosopher by serial)
  --account-id <id>        Force OpenClaw account id
  --agent-id <id>          Include isolated agent creation in follow-up command
  --model <id>             Model id for optional agent creation (default: MiniMax-M2.5)
  --no-public-check        Do not check username existence on t.me
  --json                   Emit machine-readable JSON
  -h, --help               Show help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: command not found: $1" >&2
    exit 1
  fi
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

slugify_account() {
  local name="$1"
  local serial_pad="$2"
  local base
  base="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  if [[ -z "$base" ]]; then
    base="bot"
  fi
  printf '%s-%s' "$base" "$serial_pad"
}

pick_philosopher() {
  local serial="$1"
  local idx=$((serial % ${#PHILOSOPHERS[@]}))
  printf '%s' "${PHILOSOPHERS[$idx]}"
}

username_exists_public() {
  local username="$1"
  local html
  html="$(curl -fsSL "https://t.me/${username}" 2>/dev/null || true)"
  [[ -n "$html" ]] || return 1
  # Existing public usernames usually render a title block.
  # Non-existing usernames generally do not include this block.
  rg -q '<div class="tgme_page_title">' <<<"$html"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="${2:-}"
      shift 2
      ;;
    --digits)
      DIGITS="${2:-}"
      shift 2
      ;;
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --name)
      DISPLAY_NAME="${2:-}"
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
    --json)
      EMIT_JSON=1
      shift
      ;;
    --no-public-check)
      CHECK_PUBLIC_USERNAME=0
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

if [[ -z "$PREFIX" ]]; then
  echo "ERROR: --prefix must not be empty" >&2
  exit 1
fi

if ! is_uint "$DIGITS"; then
  echo "ERROR: --digits must be an integer" >&2
  exit 1
fi
if (( DIGITS < 1 || DIGITS > 9 )); then
  echo "ERROR: --digits must be between 1 and 9" >&2
  exit 1
fi

need_cmd jq
need_cmd openclaw
need_cmd curl
need_cmd rg

status_json="$(openclaw channels status --json --probe 2>/dev/null || echo '{}')"

if [[ -z "$SERIAL" ]]; then
  used_serials="$(
    jq -r --arg prefix "$PREFIX" --argjson digits "$DIGITS" '
      ((.channelAccounts.telegram // []) | .[]?.probe.bot.username // empty)
      | select(test("^" + $prefix + "[0-9]{" + ($digits | tostring) + "}_bot$"))
      | capture("^" + $prefix + "(?<s>[0-9]+)_bot$").s
    ' <<<"$status_json" | sort -n | uniq
  )"

  next=0
  while read -r line; do
    [[ -z "$line" ]] && continue
    if (( 10#$line == next )); then
      next=$((next + 1))
    elif (( 10#$line > next )); then
      break
    fi
  done <<<"$used_serials"
  SERIAL="$next"
else
  if ! is_uint "$SERIAL"; then
    echo "ERROR: --serial must be an integer" >&2
    exit 1
  fi
fi

max_serial=$((10**DIGITS - 1))
if (( SERIAL > max_serial )); then
  echo "ERROR: serial $SERIAL exceeds max for digits=$DIGITS (max=$max_serial)" >&2
  exit 1
fi

serial_pad="$(printf "%0${DIGITS}d" "$SERIAL")"
username="${PREFIX}${serial_pad}_bot"

if (( CHECK_PUBLIC_USERNAME == 1 )); then
  # Skip occupied usernames (for example, created earlier but not yet configured locally).
  while username_exists_public "$username"; do
    SERIAL=$((SERIAL + 1))
    if (( SERIAL > max_serial )); then
      echo "ERROR: no available username left for prefix '$PREFIX' and digits=$DIGITS" >&2
      exit 1
    fi
    serial_pad="$(printf "%0${DIGITS}d" "$SERIAL")"
    username="${PREFIX}${serial_pad}_bot"
  done
fi

if [[ -z "$DISPLAY_NAME" ]]; then
  DISPLAY_NAME="$(pick_philosopher "$SERIAL")"
fi

if [[ -z "$ACCOUNT_ID" ]]; then
  ACCOUNT_ID="$(slugify_account "$DISPLAY_NAME" "$serial_pad")"
fi

add_cmd=(bash scripts/add_async_telegram_bot.sh --token "<FRESH_TOKEN_FROM_BOTFATHER>" --name "$DISPLAY_NAME" --account-id "$ACCOUNT_ID")
if [[ -n "$AGENT_ID" ]]; then
  add_cmd+=(--agent-id "$AGENT_ID" --model "$MODEL_ID")
fi

if (( EMIT_JSON == 1 )); then
  jq -n \
    --arg prefix "$PREFIX" \
    --argjson digits "$DIGITS" \
    --argjson serial "$SERIAL" \
    --arg serialPad "$serial_pad" \
    --arg username "$username" \
    --arg displayName "$DISPLAY_NAME" \
    --arg accountId "$ACCOUNT_ID" \
    --arg agentId "$AGENT_ID" \
    --arg modelId "$MODEL_ID" \
    --arg addCommand "${add_cmd[*]}" \
    '{
      prefix: $prefix,
      digits: $digits,
      serial: $serial,
      serialPad: $serialPad,
      username: $username,
      displayName: $displayName,
      accountId: $accountId,
      agentId: $agentId,
      modelId: $modelId,
      addCommand: $addCommand,
      botFather: {
        command: "/newbot",
        displayName: $displayName,
        username: $username
      }
    }'
  exit 0
fi

cat <<EOF
Bot Plan
  display name: $DISPLAY_NAME
  username:     $username
  account id:   $ACCOUNT_ID
  serial:       $SERIAL (padded: $serial_pad)
  prefix:       $PREFIX

BotFather Steps
  1) Open @BotFather
  2) Send: /newbot
  3) Name: $DISPLAY_NAME
  4) Username: $username
  5) Copy the fresh token

Follow-up Command
  ${add_cmd[*]}
EOF

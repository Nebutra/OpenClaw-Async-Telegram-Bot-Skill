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

TOKEN=""
ACCOUNT_ID=""
DISPLAY_NAME=""
AGENT_ID=""
MODEL_ID="MiniMax-M2.5"
DRY_RUN=0
RESTART_GATEWAY=1
ALLOW_EXISTING_TOKEN=0

usage() {
  cat <<'EOF'
Usage:
  add_async_telegram_bot.sh --token <token> [options]

Required:
  --token <token>            Telegram bot token from BotFather

Optional:
  --account-id <id>          OpenClaw Telegram account id
  --name <display name>      Display name (should be philosopher name)
  --agent-id <id>            Create isolated agent bound to telegram:<account-id>
  --model <id>               Model id for new agent (default: MiniMax-M2.5)
  --allow-existing-token     Allow reusing a token already registered in OpenClaw
  --skip-restart             Do not restart gateway
  --dry-run                  Print planned actions only
  -h, --help                 Show help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: command not found: $1" >&2
    exit 1
  fi
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

pick_philosopher() {
  local serial="$1"
  local idx=$((10#$serial % ${#PHILOSOPHERS[@]}))
  printf '%s' "${PHILOSOPHERS[$idx]}"
}

slugify_account() {
  local name="$1"
  local serial="$2"
  local base
  base="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  if [[ -z "$base" ]]; then
    base="bot"
  fi
  printf '%s-%s' "$base" "$serial"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --account-id)
      ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    --name)
      DISPLAY_NAME="${2:-}"
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
    --allow-existing-token)
      ALLOW_EXISTING_TOKEN=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-restart)
      RESTART_GATEWAY=0
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

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: --token is required" >&2
  usage
  exit 1
fi

need_cmd curl
need_cmd jq
need_cmd openclaw

ME_JSON="$(curl -fsS "https://api.telegram.org/bot${TOKEN}/getMe")"
if [[ "$(jq -r '.ok // false' <<<"$ME_JSON")" != "true" ]]; then
  echo "ERROR: token validation failed" >&2
  jq -r '.description // "unknown error"' <<<"$ME_JSON" >&2
  exit 1
fi

BOT_ID="$(jq -r '.result.id' <<<"$ME_JSON")"
USERNAME="$(jq -r '.result.username' <<<"$ME_JSON")"

if [[ ! "$USERNAME" =~ ^Nebutra([0-9]{3})_bot$ ]]; then
  echo "ERROR: username '$USERNAME' does not match required format Nebutra[three-digits]_bot" >&2
  exit 1
fi
SERIAL="${BASH_REMATCH[1]}"

if [[ -z "$DISPLAY_NAME" ]]; then
  DISPLAY_NAME="$(pick_philosopher "$SERIAL")"
fi

if [[ -z "$ACCOUNT_ID" ]]; then
  ACCOUNT_ID="$(slugify_account "$DISPLAY_NAME" "$SERIAL")"
fi

STATUS_JSON="$(openclaw channels status --json --probe 2>/dev/null || true)"
EXISTING_BOT_ACCOUNT="$(jq -r --argjson bot_id "$BOT_ID" '((.channelAccounts.telegram // []) | map(select((.probe.bot.id // -1) == $bot_id)) | .[0].accountId) // empty' <<<"$STATUS_JSON" 2>/dev/null || true)"

if [[ -n "$EXISTING_BOT_ACCOUNT" ]]; then
  if (( ALLOW_EXISTING_TOKEN != 1 )); then
    echo "ERROR: provided token is already registered in OpenClaw account '$EXISTING_BOT_ACCOUNT' (bot id=$BOT_ID)." >&2
    echo "For a NEW bot, create a fresh token in BotFather (/newbot)." >&2
    echo "If you intentionally want to update this existing bot, rerun with --allow-existing-token." >&2
    exit 1
  fi
  if [[ "$EXISTING_BOT_ACCOUNT" != "$ACCOUNT_ID" ]]; then
    echo "INFO: bot id $BOT_ID already exists in account '$EXISTING_BOT_ACCOUNT'; reusing it"
    ACCOUNT_ID="$EXISTING_BOT_ACCOUNT"
  fi
fi

CONFLICT_BOT_ID="$(jq -r --arg account "$ACCOUNT_ID" '((.channelAccounts.telegram // []) | map(select(.accountId == $account)) | .[0].probe.bot.id) // empty' <<<"$STATUS_JSON" 2>/dev/null || true)"
if [[ -n "$CONFLICT_BOT_ID" && "$CONFLICT_BOT_ID" != "$BOT_ID" ]]; then
  echo "ERROR: account id '$ACCOUNT_ID' already belongs to another bot id ($CONFLICT_BOT_ID)" >&2
  echo "Use --account-id with another value." >&2
  exit 1
fi

echo "Plan:"
echo "  token:      $(mask_token "$TOKEN")"
echo "  bot id:     $BOT_ID"
echo "  username:   $USERNAME"
echo "  serial:     $SERIAL"
echo "  account id: $ACCOUNT_ID"
echo "  name:       $DISPLAY_NAME"
echo "  allow-existing-token: $ALLOW_EXISTING_TOKEN"

if (( DRY_RUN == 1 )); then
  echo "DRY-RUN: openclaw channels add --channel telegram --account '$ACCOUNT_ID' --name '$DISPLAY_NAME' --token '<redacted>'"
  if [[ -n "$AGENT_ID" ]]; then
    echo "DRY-RUN: openclaw agents add '$AGENT_ID' --workspace '$HOME/.openclaw/workspaces/$AGENT_ID' --bind 'telegram:$ACCOUNT_ID' --model '$MODEL_ID' --non-interactive"
  fi
  exit 0
fi

openclaw channels add \
  --channel telegram \
  --account "$ACCOUNT_ID" \
  --name "$DISPLAY_NAME" \
  --token "$TOKEN"

if (( RESTART_GATEWAY == 1 )); then
  openclaw gateway restart >/dev/null
  sleep 2
fi

if [[ -n "$AGENT_ID" ]]; then
  AGENT_EXISTS="$(openclaw agents list --json | jq -r --arg id "$AGENT_ID" 'map(select(.id == $id)) | length')"
  if [[ "$AGENT_EXISTS" == "0" ]]; then
    openclaw agents add "$AGENT_ID" \
      --workspace "$HOME/.openclaw/workspaces/$AGENT_ID" \
      --bind "telegram:$ACCOUNT_ID" \
      --model "$MODEL_ID" \
      --non-interactive >/dev/null
    AGENT_ACTION="created"
  else
    AGENT_ACTION="exists"
  fi
else
  AGENT_ACTION="not-requested"
fi

VERIFY_JSON="$(openclaw channels status --json --probe)"
ACCOUNT_JSON="$(jq --arg account "$ACCOUNT_ID" '((.channelAccounts.telegram // []) | map(select(.accountId == $account)) | .[0])' <<<"$VERIFY_JSON")"

if [[ "$ACCOUNT_JSON" == "null" ]]; then
  echo "ERROR: account '$ACCOUNT_ID' not found after add" >&2
  exit 1
fi

RUNNING="$(jq -r '.running // false' <<<"$ACCOUNT_JSON")"
PROBE_OK="$(jq -r '.probe.ok // false' <<<"$ACCOUNT_JSON")"
PROBED_USERNAME="$(jq -r '.probe.bot.username // ""' <<<"$ACCOUNT_JSON")"

if [[ "$RUNNING" != "true" || "$PROBE_OK" != "true" ]]; then
  echo "ERROR: account '$ACCOUNT_ID' is not healthy (running=$RUNNING, probe.ok=$PROBE_OK)" >&2
  exit 1
fi

if [[ -n "$PROBED_USERNAME" && "$PROBED_USERNAME" != "$USERNAME" ]]; then
  echo "ERROR: probe username mismatch (expected=$USERNAME, actual=$PROBED_USERNAME)" >&2
  exit 1
fi

echo "SUCCESS"
echo "  account id: $ACCOUNT_ID"
echo "  username:   $USERNAME"
echo "  running:    $RUNNING"
echo "  probe.ok:   $PROBE_OK"
echo "  name:       $DISPLAY_NAME"
echo "  agent:      $AGENT_ACTION"

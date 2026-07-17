#!/bin/bash
# Daily check: if hermes's active model is provider=openrouter and it is no
# longer a free-tier model (per OpenRouter's live pricing), stop the hermes
# containers so we don't get billed unexpectedly.
set -uo pipefail

HERMES_DIR="/data01/cheoljoo.lee/code/hermes"
HERMES_CONFIG="$HOME/.hermes/config.yaml"
LOG_FILE="$HERMES_DIR/scripts/check_free_model.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

if [[ ! -f "$HERMES_CONFIG" ]]; then
    log "ERROR: config not found at $HERMES_CONFIG"
    exit 1
fi

# model.provider / model.default live under the top-level "model:" block.
read -r provider model < <(awk '
    /^model:/ { inblock=1; next }
    inblock && /^[^[:space:]]/ { inblock=0 }
    inblock && /^[[:space:]]+provider:/ { gsub(/^[[:space:]]+provider:[[:space:]]*|"/, "", $0); provider=$0 }
    inblock && /^[[:space:]]+default:/  { gsub(/^[[:space:]]+default:[[:space:]]*|"/,  "", $0); model=$0 }
    END { print provider, model }
' "$HERMES_CONFIG")

if [[ "$provider" != "openrouter" ]]; then
    log "provider='$provider' (not openrouter) - skip check"
    exit 0
fi

pricing=$(curl -fsS https://openrouter.ai/api/v1/models 2>>"$LOG_FILE" \
    | jq -r --arg id "$model" '.data[] | select(.id == $id) | "\(.pricing.prompt) \(.pricing.completion)"')

if [[ -z "$pricing" ]]; then
    log "WARN: model '$model' not found in OpenRouter model list - cannot verify, leaving hermes running"
    exit 0
fi

read -r prompt_price completion_price <<< "$pricing"

if [[ "$prompt_price" == "0" && "$completion_price" == "0" ]]; then
    log "OK: model '$model' is still free (prompt=$prompt_price completion=$completion_price)"
else
    log "ALERT: model '$model' is NOT free anymore (prompt=$prompt_price completion=$completion_price) - stopping hermes"
    ( cd "$HERMES_DIR" && docker compose stop ) >> "$LOG_FILE" 2>&1
    log "hermes stopped"
fi

#!/usr/bin/env bash
# Arranca LiveTalking SOLO si AVATAR_UI_MODE=livetalking en el .env de ctic-jAnItor.
# Si no está en ese modo, sale con 0 (systemd no lo reinicia).
set -euo pipefail

ENV_FILE="${LIVETALKING_ENV_FILE:-/opt/ctic-jAnItor/.env}"

get() {
  local key="$1"
  {
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null \
      | tail -n1 \
      | cut -d= -f2- \
      | sed -E 's/[[:space:]]+#.*$//' \
      | tr -d "\"'" \
      | xargs
  } || true
}

MODE="$(get AVATAR_UI_MODE)"
if [ "$MODE" != "livetalking" ]; then
  echo "LiveTalking: AVATAR_UI_MODE=${MODE:-<vacío>} -> no arranca"
  exit 0
fi

AVATAR="$(get LIVETALKING_AVATAR)"; AVATAR="${AVATAR:-turin9}"
DELAY="$(get AVATAR_VIDEO_DELAY_MS)"; DELAY="${DELAY:-120}"
PORT="$(get LIVETALKING_PORT)"; PORT="${PORT:-8020}"

export AVATAR_VIDEO_DELAY_MS="$DELAY"
cd /opt/livetalking
exec /opt/livetalking/.venv/bin/python app.py \
  --transport webrtc --model wav2lip --avatar_id "$AVATAR" --listenport "$PORT"

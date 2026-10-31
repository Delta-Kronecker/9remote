#!/usr/bin/env bash
set -euo pipefail

DURATION_HOURS="${1:-6}"
AUTO_APPROVE="${2:-true}"

echo "==> Starting 9Remote daemon..."
# Start 9remote in background and redirect output to a log file
9remote start > 9remote.log 2>&1 &
SERVER_PID=$!

echo "==> Waiting for 9Remote server to initialize..."
MAX_ATTEMPTS=30
ATTEMPT=0
HEALTHY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if curl -fsS http://localhost:2208/api/health >/dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  sleep 2
done

if [ "$HEALTHY" = "false" ]; then
  echo "Error: 9Remote server failed to start on port 2208 within 60 seconds."
  echo "--- 9Remote Server Logs ---"
  cat 9remote.log || true
  exit 1
fi

echo "==> 9Remote server is listening on http://localhost:2208"

if [ "$AUTO_APPROVE" = "true" ]; then
  echo "==> Enabling auto-approve for new incoming connections..."
  curl -fsS -X POST http://localhost:2208/api/device/auto-approve \
    -H "Content-Type: application/json" \
    -d '{"enabled": true}' >/dev/null 2>&1 || 9remote auto-approve on || true
fi

echo "==> Fetching connection keys and tunnel status..."
sleep 5

STATE_JSON=$(curl -fsS http://localhost:2208/api/ui/state 2>/dev/null || echo "{}")
OTK_JSON=$(curl -fsS -X POST http://localhost:2208/api/key/one-time 2>/dev/null || echo "{}")

PERM_KEY=$(echo "$STATE_JSON" | jq -r '.permanentKey // "N/A"')
TUNNEL_URL=$(echo "$STATE_JSON" | jq -r '.tunnelUrl // "N/A"')
ONE_TIME_KEY=$(echo "$OTK_JSON" | jq -r '.oneTimeKey // "N/A"')

echo ""
echo "=================================================================="
echo "                   9REMOTE GITHUB RUNNER READY                    "
echo "=================================================================="
echo " Web Login URL  : https://9remote.cc/login"
echo " Permanent Key  : ${PERM_KEY}"
echo " One-Time Key   : ${ONE_TIME_KEY} (Expires in 30 minutes)"
echo " Tunnel URL     : ${TUNNEL_URL}"
echo " Auto Approve   : ${AUTO_APPROVE}"
echo " Runner Duration: ${DURATION_HOURS} hour(s)"
echo "=================================================================="
echo " Steps to connect:"
echo " 1. Go to https://9remote.cc/login or open the 9Remote App."
echo " 2. Enter either One-Time Key [${ONE_TIME_KEY}] or Permanent Key [${PERM_KEY}]."
echo " 3. You will gain access to this interactive terminal!"
echo "=================================================================="
echo ""

DURATION_SEC=$((DURATION_HOURS * 3600))
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION_SEC))

cleanup() {
  echo "==> Gracefully shutting down 9Remote server (PID $SERVER_PID)..."
  kill -TERM "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  echo "==> Clean shutdown complete."
}
trap cleanup EXIT INT TERM

echo "==> Runner keep-alive loop initiated (Duration: ${DURATION_HOURS}h)..."

while [ $(date +%s) -lt $END_TIME ]; do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "Error: 9Remote server process died unexpectedly!"
    echo "--- Server Logs ---"
    cat 9remote.log || true
    exit 1
  fi
  sleep 60
done

echo "==> Requested duration of ${DURATION_HOURS} hour(s) reached. Exiting."

#!/usr/bin/env bash
set -euo pipefail

DURATION_HOURS="${1:-6}"
AUTO_APPROVE="${2:-true}"

echo "==> Installing better-sqlite3..."
npm install -g better-sqlite3 2>/dev/null || true

echo "==> Cleaning 9remote cache..."
rm -rf ~/.npm/_npx/*9remote* 2>/dev/null || true

echo "==> Starting 9Remote daemon..."

# Install 9remote first to get the server files
npx --yes 9remote --version

echo "==> Patching node:sqlite in 9remote server.cjs..."
# Find and patch all server.cjs files
for file in $(find ~/.npm/_npx -name "server.cjs" -path "*/9remote/dist/*" 2>/dev/null); do
  if [ -f "$file" ] && grep -q "node:sqlite" "$file" 2>/dev/null; then
    echo "Patching: $file"
    sed -i 's/node:sqlite/better-sqlite3/g' "$file"
  fi
done

# Start 9remote in background
npx --yes 9remote start > 9remote.log 2>&1 &
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
    -d '{"enabled": true}' >/dev/null 2>&1 || npx --yes 9remote auto-approve on || true
fi

echo "==> Fetching connection keys and tunnel status..."
sleep 3

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
echo " One-Time Key   : ${ONE_TIME_KEY} (Expires in 30 min)"
echo " Tunnel URL     : ${TUNNEL_URL}"
echo " Auto Approve   : ${AUTO_APPROVE}"
echo " Duration       : ${DURATION_HOURS} hour(s)"
echo "=================================================================="
echo "Connect at https://9remote.cc/login using the One-Time Key above."
echo "=================================================================="
echo ""

# Keep alive for specified duration
sleep $((DURATION_HOURS * 3600))

echo "==> Duration of ${DURATION_HOURS} hour(s) reached. Shutting down..."
kill $SERVER_PID 2>/dev/null || true

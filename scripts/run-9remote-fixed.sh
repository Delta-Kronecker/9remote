#!/bin/bash
set -euo pipefail

DURATION_HOURS="${1:-6}"
AUTO_APPROVE="${2:-true}"

echo "==> Installing better-sqlite3 globally..."
npm install -g better-sqlite3

echo "==> Downloading and patching 9remote package..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Download 9remote package without running
npm pack 9remote 2>/dev/null
TARBALL=$(ls 9remote-*.tgz 2>/dev/null | head -1)

if [ -z "$TARBALL" ]; then
  echo "ERROR: Failed to download 9remote package"
  exit 1
fi

# Extract the package
tar -xzf "$TARBALL"
PACKAGE_DIR=$(ls -d package)

echo "==> Patching server.cjs for node:sqlite compatibility..."
if [ -f "$PACKAGE_DIR/dist/server.cjs" ]; then
  sed -i 's/node:sqlite/better-sqlite3/g' "$PACKAGE_DIR/dist/server.cjs"
  echo "==> Patch applied"
else
  echo "ERROR: server.cjs not found in package"
  exit 1
fi

echo "==> Starting 9Remote daemon..."
node "$PACKAGE_DIR/dist/cli.cjs" start > "$TMPDIR/9remote.log" 2>&1 &
SERVER_PID=$!

echo "==> Waiting for server to initialize (max 60 seconds)..."
for i in $(seq 1 30); do
  if curl -fsS http://localhost:2208/api/health >/dev/null 2>&1; then
    echo "==> 9Remote server is healthy and listening on port 2208!"
    break
  fi
  sleep 2
done

if ! kill -0 $SERVER_PID 2>/dev/null; then
  echo "ERROR: 9Remote server crashed or failed to start"
  echo "--- Last 30 lines of log ---"
  tail -30 "$TMPDIR/9remote.log"
  exit 1
fi

if [ "$AUTO_APPROVE" = "true" ]; then
  echo "==> Enabling auto-approve..."
  curl -fsS -X POST http://localhost:2208/api/device/auto-approve \
    -H "Content-Type: application/json" \
    -d '{"enabled": true}' >/dev/null 2>&1 || true
fi

echo "==> Fetching connection keys..."
sleep 3

STATE_JSON=$(curl -fsS http://localhost:2208/api/ui/state 2>/dev/null || echo "{}")
OTK_RESPONSE=$(curl -fsS -X POST http://localhost:2208/api/key/one-time 2>/dev/null || echo "{}")

PERM_KEY=$(echo "$STATE_JSON" | jq -r '.permanentKey // "N/A"')
ONE_TIME_KEY=$(echo "$OTK_RESPONSE" | jq -r '.oneTimeKey // "N/A"')
TUNNEL_URL=$(echo "$STATE_JSON" | jq -r '.tunnelUrl // "N/A"')

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

# Keep alive for specified duration
sleep $((DURATION_HOURS * 3600))

echo "==> Duration completed. Shutting down..."
kill $SERVER_PID 2>/dev/null || true
trap 'rm -rf "$TMPDIR"' EXIT

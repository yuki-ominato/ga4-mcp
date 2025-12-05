#!/bin/sh
set -eu

PORT="${PORT:-8080}"
STREAM_PATH="${MCP_STREAM_PATH:-/mcp}"
API_KEY="${MCP_API_KEY:-}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SERVER_MODULE="${MCP_GA4_MODULE:-analytics_mcp.server}"

echo "[boot] node: $(node -v)"
echo "[boot] npm : $(npm -v)"

# バイナリチェック
command -v mcp-proxy >/dev/null 2>&1 || { echo "[boot] mcp-proxy not found"; exit 127; }
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || { echo "[boot] python runtime not found"; exit 127; }

echo "[boot] launching: mcp-proxy wrapping analytics-mcp server (${SERVER_MODULE})..."

# mcp-proxy の起動
exec /usr/local/bin/mcp-proxy \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --streamEndpoint "${STREAM_PATH}" \
  --sseEndpoint "${STREAM_PATH}" \
  --stateless \
  ${API_KEY:+--apiKey "${API_KEY}"} \
  "${PYTHON_BIN}" -m "${SERVER_MODULE}"

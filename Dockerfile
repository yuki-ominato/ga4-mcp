# Dockerfile
FROM node:20-slim

WORKDIR /app

# GSC版と同様の環境変数設定
ENV PORT=8080 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    UV_INSTALL_DIR=/usr/local/bin \
    MCP_GA4_MODULE=analytics_mcp.server

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Node (mcp-proxy) + Python runtime + ツール類のインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-venv python3-pip curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    npm i -g mcp-proxy@^5 && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# Python 依存関係のインストール
COPY requirements.txt .
RUN uv venv "$VIRTUAL_ENV" && \
    uv pip install --python "$VIRTUAL_ENV/bin/python" --upgrade pip && \
    uv pip install --python "$VIRTUAL_ENV/bin/python" -r requirements.txt

# ソースコードとエントリポイントのコピー
COPY analytics_mcp /app/analytics_mcp
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8080

# ヘルスチェック (mcp-proxy が提供する /ping)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/ping" || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]

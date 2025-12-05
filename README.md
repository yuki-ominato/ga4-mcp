# Google Analytics MCP Server on Cloud Run

このリポジトリは、[googleanalytics/google-analytics-mcp](https://github.com/googleanalytics/google-analytics-mcp) で公開されている公式 GA4 MCP サーバーを Cloud Run 上で常時稼働させるための Docker 構成を提供します。`analytics_mcp/` ディレクトリのコードは公式リポジトリから取得しており、コンテナ内では `mcp-proxy` が HTTP(S) エンドポイントを公開、Python ランタイムが MCP サーバー本体を実行します。

## ディレクトリ概要

- `analytics_mcp/` – 公式サーバー実装。FastMCP で各ツールを登録しており、そのまま Cloud Run で利用できます。
- `Dockerfile` – Node.js (mcp-proxy) + Python + 依存ライブラリを含むコンテナイメージを作成します。
- `entrypoint.sh` – `mcp-proxy` を起動し、`python -m analytics_mcp.server` をラップします。
- `requirements.txt` – 公式サーバーが必要とする Python 依存関係を固定しています。

## 前提条件

1. Cloud Run を利用できる Google Cloud プロジェクト
2. 有効化済み API: `analyticsadmin.googleapis.com`, `analyticsdata.googleapis.com`, `run.googleapis.com`, `cloudbuild.googleapis.com`, `artifactregistry.googleapis.com`
3. デプロイに使用するサービス アカウントが Cloud Run/Cloud Build/Artifact Registry の権限と GA4 データ閲覧権限を保持していること

## ビルドとローカル実行

```bash
# ビルド
docker build -t ga4-mcp:local .

# Application Default Credentials をマウントして起動
docker run --rm -p 8080:8080 \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/adc.json \
  -v "$HOME/.config/gcloud/application_default_credentials.json:/secrets/adc.json:ro" \
  ga4-mcp:local

# 動作確認 (mcp-proxy の /ping)
curl http://localhost:8080/ping
```

## Cloud Run へのデプロイ

1. Artifact Registry リポジトリを作成（例: `gcloud artifacts repositories create analytics-mcp --repository-format=docker --location=asia-northeast1`）。
2. Cloud Build を直接使う場合は `gcloud builds submit --tag asia-northeast1-docker.pkg.dev/PROJECT_ID/analytics-mcp/server .` で Artifact Registry へ push。
3. Cloud Run サービスへデプロイ:
   ```bash
   gcloud run deploy ga4-mcp \
     --image asia-northeast1-docker.pkg.dev/PROJECT_ID/analytics-mcp/server \
     --region asia-northeast1 \
     --allow-unauthenticated \
     --port 8080
   ```
   - サービス アカウントを限定したい場合は `--service-account` を指定し、GA4 読み取り権限と必要な Cloud Run/Artifact Registry 権限を付与してください。
   - `MCP_API_KEY` を設定すると HTTP リクエストに `Authorization: Bearer <key>` を必須にできます。

## Cloud Build (cloudbuild.yaml)

- トリガーから `cloudbuild.yaml` を参照すると、イメージビルド → Artifact Registry への push → Cloud Run デプロイを一連で実行します。
- 主要な置換変数:

| 変数 | 既定値 | 説明 |
| --- | --- | --- |
| `_REGION` | `asia-northeast1` | Artifact Registry と Cloud Run のリージョン |
| `_REPOSITORY` | `analytics-mcp` | Artifact Registry のリポジトリ名 |
| `_SERVICE` | `ga4-mcp` | Cloud Run サービス名 |
| `_DEPLOY_ARGS` | `--allow-unauthenticated` | `gcloud run deploy` に付与する追加引数 |

- Cloud Build トリガーで `build.service_account` を指定している場合でも、`cloudbuild.yaml` 内で `options.logging=CLOUD_LOGGING_ONLY` を設定済みなので追加のログバケットは不要です。
- デプロイ時に `MCP_API_KEY` や `GOOGLE_CLOUD_PROJECT` 等の環境変数を設定する場合は、Cloud Run のサービス設定で管理してください（`_DEPLOY_ARGS` に `--set-env-vars ...` を追加する方法もあります）。

## クライアント接続例 (Gemini)

Cloud Run の HTTPS エンドポイントが `https://ga4-mcp-xxxxxx.a.run.app/mcp` の場合、Gemini CLI / Code Assist の `~/.gemini/settings.json` に以下を追加します（API キーを有効化した場合は `apiKey` を同じ値にします）。

```json
{
  "mcpServers": {
    "analytics-mcp-cloud-run": {
      "url": "https://ga4-mcp-xxxxxx.a.run.app/mcp",
      "apiKey": "OPTIONAL_KEY"
    }
  }
}
```

## 環境変数

| 変数名 | 役割 |
| --- | --- |
| `PORT` | Cloud Run が割り当てるポート (既定 8080)。 |
| `MCP_STREAM_PATH` / `MCP_SSE_PATH` | mcp-proxy のエンドポイントパス (既定 `/mcp`)。 |
| `MCP_API_KEY` | Bearer 認証を必須にするオプション。 |
| `GOOGLE_CLOUD_PROJECT` | 任意。Gemini 側でプロジェクト ID を共有したい場合に設定。 |

## ライセンス

`analytics_mcp/` 以下のコードは Apache License 2.0 に従います。詳細は同梱の `LICENSE` を参照してください。

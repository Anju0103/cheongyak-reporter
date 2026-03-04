#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$PROJECT_DIR/docs/feed.json}"

RAW_URL="${CHEONGYAK_RAW_JSON_URL:-}"
if [[ -z "$RAW_URL" ]]; then
  echo "CHEONGYAK_RAW_JSON_URL is required"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
RAW_JSON="$TMP_DIR/raw.json"
trap 'rm -rf "$TMP_DIR"' EXIT

CURL_ARGS=(--fail --silent --show-error --location)
if [[ -n "${CHEONGYAK_AUTH_HEADER:-}" ]]; then
  CURL_ARGS+=(--header "$CHEONGYAK_AUTH_HEADER")
fi

curl "${CURL_ARGS[@]}" "$RAW_URL" -o "$RAW_JSON"

"$PROJECT_DIR/scripts/generate_feed.py" \
  --input "$RAW_JSON" \
  --output "$OUTPUT_PATH" \
  --regions "${CHEONGYAK_REGIONS:-서울,경기}" \
  --keywords "${CHEONGYAK_KEYWORDS:-무순위,잔여,계약취소,사후}"

echo "Generated feed: $OUTPUT_PATH"

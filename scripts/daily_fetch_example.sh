#!/bin/zsh
set -euo pipefail

# Usage example (fill environment variables first):
#   export CHEONGYAK_RAW_JSON_URL='https://example.com/raw.json'
#   export OUTPUT_DIR='/path/to/public'
#   ./scripts/daily_fetch_example.sh

if [[ -z "${CHEONGYAK_RAW_JSON_URL:-}" ]]; then
  echo "CHEONGYAK_RAW_JSON_URL is required"
  exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/build/feed}"
RAW_JSON="$OUTPUT_DIR/raw.json"
FEED_JSON="$OUTPUT_DIR/feed.json"

mkdir -p "$OUTPUT_DIR"

curl -fsSL "$CHEONGYAK_RAW_JSON_URL" -o "$RAW_JSON"
./scripts/generate_feed.py \
  --input "$RAW_JSON" \
  --output "$FEED_JSON" \
  --regions 서울,경기 \
  --keywords 무순위,잔여,계약취소,사후

echo "Generated: $FEED_JSON"

#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$PROJECT_DIR/docs/feed.json}"

default_date_from="$(python3 - <<'PY'
from datetime import date, timedelta
print((date.today() - timedelta(days=120)).isoformat())
PY
)"

RAW_URL="${CHEONGYAK_RAW_JSON_URL:-}"
if [[ -z "$RAW_URL" ]]; then
  date_from="${CHEONGYAK_DATE_FROM:-$default_date_from}"
  RAW_URL="https://api.odcloud.kr/api/ApplyhomeInfoDetailSvc/v1/getRemndrLttotPblancDetail?page=1&perPage=1000&returnType=JSON&cond%5BHOUSE_SECD::EQ%5D=04&cond%5BRCRIT_PBLANC_DE::GTE%5D=${date_from}"
fi

SERVICE_KEY="${CHEONGYAK_SERVICE_KEY:-}"
if [[ -n "$SERVICE_KEY" ]]; then
  encoded_key="$(python3 - "$SERVICE_KEY" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote_plus(sys.argv[1]))
PY
)"
  if [[ "$RAW_URL" == *"__SERVICE_KEY__"* ]]; then
    RAW_URL="${RAW_URL//__SERVICE_KEY__/$encoded_key}"
  elif [[ "$RAW_URL" != *"serviceKey="* ]]; then
    sep="?"
    [[ "$RAW_URL" == *"?"* ]] && sep="&"
    RAW_URL="${RAW_URL}${sep}serviceKey=${encoded_key}"
  fi
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

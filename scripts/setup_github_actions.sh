#!/bin/zsh
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  ./scripts/setup_github_actions.sh \
    --repo OWNER/REPO \
    [--raw-url https://example.com/raw.json] \
    [--service-key '<DATA_GO_KR_SERVICE_KEY>'] \
    [--auth-header 'Authorization: Bearer ...'] \
    [--date-from '2026-01-01'] \
    [--regions '서울,경기'] \
    [--keywords '무순위,잔여,계약취소,사후']

Description:
  Configure required GitHub Actions secret/variables for daily feed workflow.
USAGE
}

REPO=""
RAW_URL=""
SERVICE_KEY=""
AUTH_HEADER=""
DATE_FROM=""
REGIONS="서울,경기"
KEYWORDS="무순위,잔여,계약취소,사후"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --raw-url)
      RAW_URL="$2"
      shift 2
      ;;
    --service-key)
      SERVICE_KEY="$2"
      shift 2
      ;;
    --auth-header)
      AUTH_HEADER="$2"
      shift 2
      ;;
    --date-from)
      DATE_FROM="$2"
      shift 2
      ;;
    --regions)
      REGIONS="$2"
      shift 2
      ;;
    --keywords)
      KEYWORDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "--repo is required"
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required"
  exit 1
fi

echo "[1/4] Checking gh authentication..."
gh auth status >/dev/null

if [[ -n "$RAW_URL" ]]; then
  echo "[2/6] Setting secret: CHEONGYAK_RAW_JSON_URL"
  printf '%s' "$RAW_URL" | gh secret set CHEONGYAK_RAW_JSON_URL --repo "$REPO"
else
  echo "[2/6] Skipping CHEONGYAK_RAW_JSON_URL (not provided; default official endpoint will be used)"
fi

if [[ -n "$SERVICE_KEY" ]]; then
  echo "[3/6] Setting secret: CHEONGYAK_SERVICE_KEY"
  printf '%s' "$SERVICE_KEY" | gh secret set CHEONGYAK_SERVICE_KEY --repo "$REPO"
else
  echo "[3/6] Skipping CHEONGYAK_SERVICE_KEY (not provided)"
fi

if [[ -n "$AUTH_HEADER" ]]; then
  echo "[4/6] Setting secret: CHEONGYAK_AUTH_HEADER"
  printf '%s' "$AUTH_HEADER" | gh secret set CHEONGYAK_AUTH_HEADER --repo "$REPO"
else
  echo "[4/6] Skipping CHEONGYAK_AUTH_HEADER (not provided)"
fi

echo "[5/6] Setting variables"
if [[ -n "$DATE_FROM" ]]; then
  gh variable set CHEONGYAK_DATE_FROM --body "$DATE_FROM" --repo "$REPO"
else
  gh variable delete CHEONGYAK_DATE_FROM --repo "$REPO" >/dev/null 2>&1 || true
fi
gh variable set CHEONGYAK_REGIONS --body "$REGIONS" --repo "$REPO"
gh variable set CHEONGYAK_KEYWORDS --body "$KEYWORDS" --repo "$REPO"

echo "[6/6] Done"
echo "Done. Trigger workflow manually:"
echo "  gh workflow run 'Daily Cheongyak Feed' --repo $REPO"

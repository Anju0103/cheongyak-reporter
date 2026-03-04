#!/bin/zsh
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  ./scripts/setup_github_actions.sh \
    --repo OWNER/REPO \
    --raw-url https://example.com/raw.json \
    [--auth-header 'Authorization: Bearer ...'] \
    [--regions '서울,경기'] \
    [--keywords '무순위,잔여,계약취소,사후']

Description:
  Configure required GitHub Actions secret/variables for daily feed workflow.
USAGE
}

REPO=""
RAW_URL=""
AUTH_HEADER=""
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
    --auth-header)
      AUTH_HEADER="$2"
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

if [[ -z "$REPO" || -z "$RAW_URL" ]]; then
  echo "--repo and --raw-url are required"
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required"
  exit 1
fi

echo "[1/4] Checking gh authentication..."
gh auth status >/dev/null

echo "[2/4] Setting secret: CHEONGYAK_RAW_JSON_URL"
printf '%s' "$RAW_URL" | gh secret set CHEONGYAK_RAW_JSON_URL --repo "$REPO"

if [[ -n "$AUTH_HEADER" ]]; then
  echo "[3/4] Setting secret: CHEONGYAK_AUTH_HEADER"
  printf '%s' "$AUTH_HEADER" | gh secret set CHEONGYAK_AUTH_HEADER --repo "$REPO"
else
  echo "[3/4] Skipping CHEONGYAK_AUTH_HEADER (not provided)"
fi

echo "[4/4] Setting variables"
gh variable set CHEONGYAK_REGIONS --body "$REGIONS" --repo "$REPO"
gh variable set CHEONGYAK_KEYWORDS --body "$KEYWORDS" --repo "$REPO"

echo "Done. Trigger workflow manually:"
echo "  gh workflow run 'Daily Cheongyak Feed' --repo $REPO"

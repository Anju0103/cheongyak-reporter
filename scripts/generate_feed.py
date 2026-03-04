#!/usr/bin/env python3
"""Generate app feed JSON for Cheongyak Reporter.

Input can be:
- Local JSON file path
- HTTP(S) URL returning JSON

The script tries to discover common field names used in subscription notice datasets,
then filters for Seoul/Gyeonggi + unsold/reallocation style notices.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from urllib.request import urlopen


def load_json(input_value: str) -> Any:
  parsed = urlparse(input_value)
  if parsed.scheme in {"http", "https"}:
    with urlopen(input_value, timeout=20) as response:
      return json.loads(response.read().decode("utf-8"))

  path = Path(input_value)
  return json.loads(path.read_text(encoding="utf-8"))


def find_items(payload: Any) -> list[dict[str, Any]]:
  if isinstance(payload, list):
    return [row for row in payload if isinstance(row, dict)]

  if not isinstance(payload, dict):
    return []

  for key in ["items", "item", "data", "list", "records", "result", "response"]:
    value = payload.get(key)
    if isinstance(value, list):
      return [row for row in value if isinstance(row, dict)]
    if isinstance(value, dict):
      nested = find_items(value)
      if nested:
        return nested

  # 마지막 fallback: 최상위 dict의 value 중 list 우선 탐색
  for value in payload.values():
    if isinstance(value, list):
      rows = [row for row in value if isinstance(row, dict)]
      if rows:
        return rows

  return []


def pick(row: dict[str, Any], keys: list[str]) -> str:
  for key in keys:
    if key in row and row[key] is not None:
      value = str(row[key]).strip()
      if value:
        return value
  return ""


def normalize_date(text: str) -> str:
  value = text.strip()
  if not value:
    return ""

  digits = "".join(ch for ch in value if ch.isdigit())
  if len(digits) >= 8:
    y, m, d = digits[:4], digits[4:6], digits[6:8]
    return f"{y}-{m}-{d}"

  return value


def classify_and_filter(
  rows: list[dict[str, Any]],
  regions: list[str],
  keywords: list[str],
) -> list[dict[str, str]]:
  region_keys = [
    "region", "sido", "sidoNm", "시도", "광역시도", "CNP_CD_NM", "ADDR", "address"
  ]
  city_keys = ["city", "sigungu", "sigunguNm", "시군구", "구군", "HSSGG_NM"]
  title_keys = [
    "title", "공고명", "PBLANC_NM", "HOUSE_NM", "APT_NM", "houseName", "name"
  ]
  category_keys = [
    "category", "공급유형", "HOUSE_SECD_NM", "specialType", "type", "noticeType"
  ]
  announce_keys = [
    "announcementDate", "공고일", "PBLANC_DE", "RCRIT_PBLANC_DE", "date"
  ]
  apply_start_keys = ["applyStartDate", "RCEPT_BGNDE", "접수시작일", "startDate"]
  apply_end_keys = ["applyEndDate", "RCEPT_ENDDE", "접수종료일", "endDate"]
  url_keys = ["url", "detailUrl", "link", "PBLANC_URL", "HMPG_ADRES"]
  id_keys = ["id", "PBLANC_NO", "HOUSE_MANAGE_NO", "noticeId", "공고번호"]

  normalized_regions = [r.strip() for r in regions if r.strip()]
  normalized_keywords = [k.strip() for k in keywords if k.strip()]

  items: list[dict[str, str]] = []

  for row in rows:
    region = pick(row, region_keys)
    city = pick(row, city_keys)
    title = pick(row, title_keys)
    category = pick(row, category_keys)
    announce = normalize_date(pick(row, announce_keys))
    apply_start = normalize_date(pick(row, apply_start_keys))
    apply_end = normalize_date(pick(row, apply_end_keys))
    url = pick(row, url_keys)

    region_text = f"{region} {city} {title}".strip()
    if normalized_regions and not any(token in region_text for token in normalized_regions):
      continue

    keyword_text = f"{title} {category}".strip()
    if normalized_keywords and not any(token in keyword_text for token in normalized_keywords):
      continue

    raw_id = pick(row, id_keys)
    if not raw_id:
      raw_id = hashlib.sha1(
        f"{region}|{city}|{title}|{announce}|{apply_start}|{apply_end}".encode("utf-8")
      ).hexdigest()[:16]

    if not title:
      # 제목이 비어 있으면 운영 가치가 낮아 제외
      continue

    items.append(
      {
        "id": raw_id,
        "region": region or "-",
        "city": city or "-",
        "title": title,
        "category": category or "무순위/잔여세대",
        "announcementDate": announce or "-",
        "applyStartDate": apply_start,
        "applyEndDate": apply_end,
        "source": "청약홈",
        "url": url,
      }
    )

  return items


def main() -> int:
  parser = argparse.ArgumentParser(description="Generate cheongyak reporter feed JSON")
  parser.add_argument("--input", required=True, help="Input JSON file path or URL")
  parser.add_argument("--output", required=True, help="Output feed JSON path")
  parser.add_argument(
    "--regions",
    default="서울,경기",
    help="Comma-separated region filters (default: 서울,경기)",
  )
  parser.add_argument(
    "--keywords",
    default="무순위,잔여,계약취소,사후",
    help="Comma-separated keyword filters",
  )
  args = parser.parse_args()

  try:
    payload = load_json(args.input)
  except Exception as error:  # noqa: BLE001
    print(f"[ERROR] Failed to load input JSON: {error}", file=sys.stderr)
    return 1

  rows = find_items(payload)
  if not rows:
    print("[ERROR] Could not find item rows from input JSON.", file=sys.stderr)
    return 1

  items = classify_and_filter(
    rows,
    regions=[value.strip() for value in args.regions.split(",")],
    keywords=[value.strip() for value in args.keywords.split(",")],
  )

  output_payload = {
    "generatedAt": datetime.now(timezone.utc).astimezone().isoformat(),
    "source": "청약홈",
    "items": items,
  }

  output_path = Path(args.output)
  output_path.parent.mkdir(parents=True, exist_ok=True)
  output_path.write_text(
    json.dumps(output_payload, ensure_ascii=False, indent=2),
    encoding="utf-8",
  )

  print(f"[OK] wrote {len(items)} items to {output_path}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())

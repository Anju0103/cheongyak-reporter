# 청약리포터 (iOS Swift)

청약홈 데이터(서울/경기 무순위·잔여세대)를 매일 확인하고 요약 알림을 받는 iPhone 앱 MVP입니다.

## 구현된 기능

- 서울/경기 필터: 지역별 ON/OFF
- 일일 리포트 화면: 전체 건수, 신규 건수, 기준 시각
- 신규 공고 감지: 이전 동기화 대비 `NEW` 표시
- 공고 링크 열기: 앱에서 청약홈 공고 URL 바로 열기
- 일일 로컬 알림: 매일 지정 시각 요약 알림
- 피드 URL 설정: 외부 JSON 피드를 앱에서 직접 변경 가능
- 샘플 데이터 포함: `Runner/sample_feed.json`

## 실행 방법

1. Xcode에서 `Runner.xcodeproj` 열기
2. 실기기(iPhone) 선택
3. `Runner` 스킴 실행

프로젝트 경로:

```bash
cd /Users/hongju/Documents/청약리포터
```

서명 없이 컴파일 검증:

```bash
xcodebuild -project Runner.xcodeproj -scheme Runner -configuration Debug \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 무료 개인 테스트 설정

- Bundle ID: `com.hongju.cheongyakreporter.personal`
- Development Team: `Y86CBU3XP3` (Personal Team)
- iPhone 전용: `TARGETED_DEVICE_FAMILY=1`

개인 테스트 빌드:

```bash
cd /Users/hongju/Documents/청약리포터
./scripts/personal_test_build.sh
```

## 피드(JSON) 형식

앱은 아래 형식의 JSON을 읽습니다.

```json
{
  "generatedAt": "2026-03-04T09:00:00+09:00",
  "source": "청약홈",
  "items": [
    {
      "id": "20260304-seoul-001",
      "region": "서울",
      "city": "강남구",
      "title": "OO아파트 무순위 입주자모집",
      "category": "APT 무순위/잔여세대",
      "announcementDate": "2026-03-04",
      "applyStartDate": "2026-03-06",
      "applyEndDate": "2026-03-06",
      "source": "청약홈",
      "url": "https://www.applyhome.co.kr"
    }
  ]
}
```

## 피드 생성 스크립트

공공데이터/청약홈 API 응답 JSON을 앱 피드 형식으로 변환:

```bash
cd /Users/hongju/Documents/청약리포터
./scripts/generate_feed.py \
  --input raw_api_response.json \
  --output feed.json \
  --regions 서울,경기 \
  --keywords 무순위,잔여,계약취소,사후
```

결과 `feed.json` URL을 앱 설정의 `JSON 피드 URL`에 넣으면 됩니다.

일일 자동 실행 예시 스크립트:

```bash
export CHEONGYAK_RAW_JSON_URL='https://example.com/raw.json'
export OUTPUT_DIR="$PWD/build/feed"
./scripts/daily_fetch_example.sh
```

## 데이터 소스(공식)

- 공공데이터포털 청약홈 API 목록(국토교통부):
  https://www.data.go.kr/data/15098547/openapi.do
- Swagger JSON:
  https://infuser.odcloud.kr/api/stages/37000/api-docs
- 한국부동산원(REB) 공공데이터 API 기술문서 공지:
  https://www.reb.or.kr/r-one/bbs/view.do?mId=0502000000&ptIdx=569&bIdx=104975&pIdx=100

## 중요한 운영 메모

- iOS 로컬 알림은 백그라운드 동기화 보장이 약합니다.
- "매일 자동 리포트" 정확도를 높이려면 서버(예: GitHub Actions)에서 피드를 매일 갱신하고,
  앱은 그 결과 JSON만 받아보는 구조를 권장합니다.

## GitHub Actions 일일 자동화

워크플로 파일:
- `.github/workflows/daily-feed.yml` (매일 KST 08:30 실행)

필수 GitHub Secret:
- `CHEONGYAK_SERVICE_KEY`: 공공데이터포털에서 발급받은 인증키

선택 GitHub Secret:
- `CHEONGYAK_RAW_JSON_URL`: 원본 API(JSON) URL (미지정 시 공식 무순위 엔드포인트 자동 사용)
- `CHEONGYAK_AUTH_HEADER`: 인증 헤더가 필요할 때 사용  
  예: `Authorization: Bearer abc...`

선택 GitHub Variables:
- `CHEONGYAK_REGIONS` (기본: `서울,경기`)
- `CHEONGYAK_KEYWORDS` (기본: `무순위,잔여,계약취소,사후`)

워크플로 동작:
1. 원본 JSON 수집
2. `scripts/generate_feed.py`로 앱 피드 형식 변환
3. `docs/feed.json` 갱신
4. 변경 시 자동 커밋/푸시

앱 설정의 `JSON 피드 URL` 예시:
- `https://<YOUR_GITHUB_USERNAME>.github.io/<YOUR_REPO_NAME>/feed.json`
- 현재 저장소 URL: `https://anju0103.github.io/cheongyak-reporter/feed.json`

CLI로 Secrets/Variables 자동 설정:

```bash
cd /Users/hongju/Documents/청약리포터
./scripts/setup_github_actions.sh \
  --repo <OWNER/REPO> \
  --service-key '<DATA_GO_KR_SERVICE_KEY>'
```

공식 무순위 API 엔드포인트(기본값):

```text
https://api.odcloud.kr/api/ApplyhomeInfoDetailSvc/v1/getRemndrLttotPblancDetail
```

기본 스크립트 동작:
- `CHEONGYAK_RAW_JSON_URL` 미지정 시 공식 엔드포인트 사용
- `CHEONGYAK_SERVICE_KEY`가 있으면 `serviceKey` 자동 주입
- `CHEONGYAK_DATE_FROM`가 있으면 시작일 필터 적용(없으면 최근 120일 기본)

워크플로 수동 실행:

```bash
gh workflow run 'Daily Cheongyak Feed' --repo <OWNER/REPO>
```

## 서명 점검

현재 Mac에서 Xcode 계정/인증서 인식 상태를 즉시 확인:

```bash
cd /Users/hongju/Documents/청약리포터
./scripts/check_signing_env.sh
```

## 주요 파일

- 앱 UI/로직: `Runner/SceneDelegate.swift`
- 앱 엔트리: `Runner/AppDelegate.swift`
- 앱 설정: `Runner/Info.plist`
- 프로젝트 설정: `Runner.xcodeproj/project.pbxproj`
- 샘플 피드: `Runner/sample_feed.json`
- 피드 변환 스크립트: `scripts/generate_feed.py`
- 일일 실행 스크립트: `scripts/run_daily_feed.sh`
- GitHub 설정 스크립트: `scripts/setup_github_actions.sh`
- 서명 점검 스크립트: `scripts/check_signing_env.sh`
- 자동화 워크플로: `.github/workflows/daily-feed.yml`

# hermes docker

[Nous Research의 Hermes Agent](https://github.com/NousResearch/hermes-agent)를 Docker로 설치/실행하기 위한 저장소입니다.

📖 **문서**
- [guide.md](guide.md) — 초보자용 전체 설치 및 운영 가이드 (API 키 발급 방법 포함)
- [telegram.md](telegram.md) — Telegram 대화 내역 및 작업 이력 정리

이 저장소는 Hermes Agent 소스를 직접 포함(vendoring)하지 않습니다. 대신
`docker-compose.yml`의 빌드 컨텍스트가 업스트림 GitHub 저장소(특정 릴리즈
태그로 고정)를 직접 가리키므로, `docker compose build` 실행 시 Docker가
알아서 해당 소스를 받아와 이미지를 빌드합니다.

## 사전 준비

- Docker Engine 및 Docker Compose v2
- 최소 1개의 LLM 제공자 API 키 (예: [OpenRouter](https://openrouter.ai/keys))

## 설치 및 실행

```bash
cp .env.example .env
# .env 파일을 열어 OPENROUTER_API_KEY 등 최소 1개의 키를 입력

HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d --build
```

- `HERMES_UID`/`HERMES_GID`는 컨테이너 안에서 사용할 사용자 ID로, 호스트의
  `~/.hermes` 디렉터리(설정/데이터가 저장되는 위치)를 소유한 사용자와
  맞춰주면 파일 권한 문제가 없습니다.
- 최초 빌드는 Node/Playwright/Python 의존성을 모두 받기 때문에 다소 시간이
  걸립니다.
- `.env`에도 `HERMES_UID`/`HERMES_GID`를 고정 기입해뒀습니다 (docker compose가
  `.env`를 변수 보간에 자동으로 읽으므로). **`-e HERMES_UID=... HERMES_GID=...`
  없이 `docker compose up`/`restart`를 실행해도 항상 올바른 값(호스트 계정)이
  적용됩니다.** 만약 이 값 없이(또는 다른 값으로) 컨테이너를 재생성하면
  `~/.hermes` 안 파일 소유권이 뒤섞여 kanban 등에서 `PermissionError`/500
  에러가 날 수 있습니다 — 그럴 땐 `docker compose exec -u root gateway
  chown -R $(id -u):$(id -g) /opt/data`로 복구하세요.

## 초기 설정

컨테이너가 뜨면 대화형 설정 마법사로 모델/도구 등을 구성합니다.

```bash
docker compose exec gateway hermes setup
```

모델만 바꾸고 싶다면:

```bash
docker compose exec gateway hermes model
```

## 커스텀 모델 provider 추가하기 (예: EXAONE)

`plugins/<provider-name>/` 아래에 `__init__.py` + `plugin.yaml`을 추가하면
이미지 재빌드 없이 새 provider가 등록됩니다 (`docker-compose.yml`이 이
디렉터리를 `/opt/data/plugins/model-providers`로 마운트합니다). 예시로
`plugins/exaone/`에 LGE AILab EXACODE SWE API 연동이 들어있습니다.

```bash
# .env에 EXAONE_API_KEY=... 채운 뒤
docker compose up -d   # 마운트 반영을 위해 재시작

docker compose exec gateway hermes config set model.provider exaone
docker compose exec gateway hermes config set model.default Chat-EXACODE-A
docker compose exec gateway hermes config set model.base_url http://exacode-chat.lge.com/v1

# 테스트
docker compose exec gateway hermes -z "1+1은?"
```

새 provider를 추가하려면 `plugins/<name>/__init__.py`에서
`providers.base.ProviderProfile`을 만들어 `register_provider()`로 등록하면
됩니다. (`env_vars`, `base_url`, `default_headers` 등 — 자세한 예시는
`plugins/exaone/__init__.py` 참고.)

## 상태 확인

`docker compose` 명령들은 이 저장소 디렉터리(`docker-compose.yml`이 있는
곳)에서 실행해야 합니다. 다른 위치에서 실행하면 `no configuration file
provided: not found` 에러가 납니다. 다른 디렉터리에서 실행해야 한다면
`-f <이 저장소 경로>/docker-compose.yml`을 붙이세요.

```bash
docker compose ps                 # 컨테이너 떠 있는지 (Up/Exited)
docker compose logs -f gateway    # 실시간 로그
docker compose logs --tail=50 gateway
```

hermes 앱 자체 상태(모델/provider, API 키, 인증, 메신저 연동 여부)는 컨테이너
안에서 확인합니다.

```bash
docker compose exec gateway hermes status
docker compose exec gateway hermes config show
```

## 명령 내리기 / 대화하기

```bash
# 한 번만 질문 (non-interactive, 스크립트/cron에서 사용 가능)
docker compose exec gateway hermes -z "1+1은?"

# 대화형 세션 (인터랙티브 터미널 필요 — -it 필수)
docker compose exec -it gateway hermes chat

# 모델/provider 변경 (인터랙티브)
docker compose exec -it gateway hermes model
```

## 대시보드 보기

`dashboard` 서비스는 보안상 기본적으로 호스트의 `127.0.0.1:9119`에만
바인딩됩니다 (API 키를 저장하므로 인증 없이 외부에 노출하지 않기 위함). 이
서버가 GUI 없는 headless Linux인 경우, 서버가 아니라 **로컬 PC(작업 중인
Windows/Mac 등)의 브라우저**로 봐야 합니다.

- **VSCode Remote-SSH 사용 시 (가장 쉬움)**: 하단 "PORTS" 탭 → *Forward a
  Port* → `9119` 입력 → 생성된 Local Address 링크를 클릭하면 로컬 브라우저에서
  바로 열립니다.
- **수동 SSH 터널**: 로컬 PC 터미널에서
  ```bash
  ssh -L 9119:localhost:9119 <host>
  ```
  연결을 유지한 채 로컬 브라우저에서 `http://localhost:9119` 접속.

## 메신저 연동 (Telegram)

`.env`에 `TELEGRAM_BOT_TOKEN`만 채우면 자동으로 활성화됩니다 ([@BotFather](https://t.me/BotFather)에게 `/newbot`으로 토큰 발급).

```bash
# .env에 TELEGRAM_BOT_TOKEN=... 채운 뒤
docker compose up -d gateway   # 반영을 위해 재시작
docker compose exec gateway hermes status   # Messaging Platforms → Telegram: configured 확인
```

보안상 모르는 사용자의 DM은 기본적으로 거부되고 pairing으로 승인해야 합니다.

```bash
# 1. Telegram에서 봇에게 아무 메시지나 전송 → 봇이 pairing 코드로 답장
# 2. 그 코드로 승인
docker compose exec gateway hermes pairing approve telegram <코드>
```

## Kanban (멀티 에이전트 작업 큐)

대시보드의 Kanban 탭에서 티켓을 만들면, 다음 조건을 만족할 때 **사람 개입 없이 자동으로 실행**됩니다.

- **담당자(assignee)를 지정**해야 함 — 비워두면 `todo`에 머물고 아무도 실행하지 않음 (현재 등록된 profile: `default`)
- **Triage 체크박스는 끄고** 만들어야 함 — triage는 별도 스펙 정리용 LLM(`auxiliary.triage_specifier`)이 필요한데 현재 미설정 상태라, triage로 만들면 그대로 멈춤
- gateway가 떠 있어야 함 (내장 dispatcher가 60초 간격으로 ready 작업을 감지해 담당 profile을 worker로 실행)

## 데이터 위치 (컨테이너 ↔ 호스트 매핑)

| 컨테이너 경로 | 호스트 경로 | 내용 |
|---|---|---|
| `/opt/data` | `~/.hermes` | config.yaml, kanban.db, sessions, logs 등 전체 상태/데이터 |
| `/opt/data/plugins/model-providers` | `./plugins` (이 저장소) | 커스텀 model provider 플러그인 (읽기전용) |

컨테이너를 `docker compose down`으로 지워도 위 호스트 경로의 내용은 그대로 남습니다.

## 매일 free 모델 감시 (비용 방지)

`scripts/check_free_model.sh`가 매일 08:00(KST)에 crontab으로 실행되어, 현재 모델의
provider가 `openrouter`이고 더 이상 free tier가 아니게 되면(OpenRouter 공개 API로
실시간 가격 조회) 자동으로 `docker compose stop`을 실행합니다. provider가
openrouter가 아니면(exaone 등) 아무 동작도 하지 않고 스킵합니다. 로그는
`scripts/check_free_model.log`에 남습니다.

```bash
crontab -l | grep check_free_model   # 등록된 스케줄 확인
```

## 버전 업데이트

`docker-compose.yml`의 `HERMES_AGENT_REF` (기본값 `v2026.7.1`)를 원하는
[릴리즈 태그](https://github.com/NousResearch/hermes-agent/tags)로 바꾼 뒤
다시 빌드하면 됩니다.

```bash
HERMES_AGENT_REF=v2026.7.1 docker compose up -d --build
```

## 중지/삭제

```bash
docker compose down
```

설정과 대화 기록은 호스트의 `~/.hermes`에 남습니다. 완전히 초기화하려면
이 디렉터리를 함께 삭제하세요.

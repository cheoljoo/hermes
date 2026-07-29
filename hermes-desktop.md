# Hermes Desktop 앱을 docker Hermes에 연결하기

> 이 문서는 로컬 PC에 설치한 **Hermes Desktop 앱**을, 이 저장소의 `docker-compose.yml`로 이
> 서버(`lotto645.lge.com`)에서 돌리고 있는 **docker 기반 Hermes**에 연결해서 같은 설정/모델/세션을
> 공유해 쓰는 방법을 정리한 가이드입니다.

---

## 1. 왜 Desktop 앱이 처음에 LLM을 새로 고르라고 하는가

Hermes Desktop 앱은 CLI/gateway와 **같은 agent core**를 쓰지만, 기본 동작은 다음과 같습니다.

- 앱을 처음 실행하면 **자기 PC에 독립된 로컬 backend**(`hermes serve`)를 새로 설치해서 씁니다.
- 이 로컬 backend는 이 서버(docker)의 `~/.hermes` 설정(API 키, 모델, 세션 등)과 **전혀 별개**의
  새 `HERMES_HOME`(맥/리눅스는 `~/.hermes`, 윈도우는 `%LOCALAPPDATA%\hermes`)을 만듭니다.
- 그래서 처음 켰을 때 API 키/모델 설정이 없어 LLM을 새로 고르라는 화면이 뜨는 것입니다.

서버 쪽에 이미 설정된 모델/키/세션을 그대로 쓰려면, 로컬 backend 대신 **원격 backend에 연결**하도록
Desktop 앱을 설정해야 합니다. ("원격 backend"란 서버에서 돌아가는 `hermes serve`/`hermes dashboard`
프로세스를 말하며, Desktop 앱은 여기에 JSON-RPC/WebSocket으로 붙습니다.)

---

## 2. 서버 쪽 설정 (이미 이 저장소에 반영됨)

이 저장소의 `docker-compose.yml`은 `dashboard` 서비스로 원격 backend 역할을 겸합니다
(`hermes dashboard --host ... --no-open`도 headless로 쓰면 `hermes serve`와 동일한 backend 역할을
합니다).

### 2.1 network_mode: host — docker 포트포워딩은 필요 없음

이 compose 파일은 `network_mode: host`를 씁니다. 즉 컨테이너가 호스트의 네트워크를 그대로 쓰기
때문에 **docker의 `-p`/포트포워딩 개념 자체가 적용되지 않습니다** (`ports:` 항목을 넣어도
무시됩니다). 대신 컨테이너 안의 프로세스가 어느 주소에 bind하는지가 곧 호스트에서 보이는 주소입니다.

```yaml
# docker-compose.yml (dashboard 서비스)
command: ["dashboard", "--host", "0.0.0.0", "--no-open"]
```

`--host 127.0.0.1`(기본값)이면 이 서버 자신만 접근 가능하고, `--host 0.0.0.0`으로 바꿔야 다른 PC
(Desktop 앱)에서 접근할 수 있습니다.

### 2.2 비루프백 bind 시 인증이 자동으로 강제됨

`0.0.0.0`처럼 외부에서 접근 가능한 주소에 bind하면 Hermes가 자동으로 인증을 요구합니다
(`--insecure` 옵션은 더 이상 이걸 끌 수 없음). 사내망 안에서만 쓰는 경우엔 username/password 방식이
간단합니다. `.env`에 다음을 추가합니다 (실제 값은 `.env` 파일 참고 — 이 문서에는 값을 적지 않습니다):

```bash
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=<강한 비밀번호>
# 재시작해도 로그인이 풀리지 않도록 고정 시크릿 지정 (없으면 재시작마다 랜덤 재생성되어 로그아웃됨)
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<openssl rand -base64 32 로 생성>
```

### 2.3 반영 및 재기동

```bash
HERMES_UID=1003 HERMES_GID=1003 docker compose up -d dashboard
```

(`.env`가 바뀌면 `env_file`을 공유하는 `gateway` 컨테이너도 같이 recreate될 수 있습니다 — Telegram
게이트웨이 등 정상 동작 여부를 `docker compose exec gateway hermes status`로 확인해두면 좋습니다.)

### 2.4 서버 쪽 검증

```bash
curl -sS http://127.0.0.1:9119/api/status
curl -sS http://lotto645.lge.com:9119/api/status
```

정상이면 아래처럼 `auth_required: true`, `auth_providers: ["basic"]`가 보여야 합니다.

```json
{"auth_required": true, "auth_providers": ["basic"], "gateway_running": ...}
```

> `gateway_running: false`는 이 상태 API가 **dashboard 컨테이너 자신의 관점**에서 보는 값이라
> 정상입니다. 실제 Telegram 등 메시징 게이트웨이는 별도의 `gateway` 컨테이너에서 돌아가므로,
> 그쪽 상태는 `docker compose exec gateway hermes status`로 따로 확인해야 합니다.

---

## 3. Desktop 앱 쪽 설정

1. **Settings → Gateway → Remote gateway**로 이동.
2. **Remote URL**에 `http://lotto645.lge.com:9119` 입력.
3. **Sign in** 클릭 → username/password 입력창이 뜨면 2.2에서 설정한 계정으로 로그인.
   - Sign in 버튼 대신 "session token을 직접 입력하라"는 창이 뜨면, 서버가 basic auth 계정을 아직
     제대로 못 읽은 상태 (`.env` 값 확인 → `docker compose restart dashboard`).
4. **Save and reconnect** 클릭 → Desktop 앱이 로컬 backend 대신 이 원격 backend로 전환됨.
5. 정상 연결되면 별도 LLM 선택 화면 없이 서버와 동일한 모델(예: `Chat-EXACODE-A`)이 바로 뜨고 채팅이
   가능합니다. 서버 쪽 Telegram 세션 등도 세션 목록에 같이 보입니다 (같은 `HERMES_HOME`을 공유하기
   때문).

> Remote URL은 `HERMES_DESKTOP_REMOTE_URL` 환경변수로 앱 실행 전에 미리 지정할 수도 있습니다
> (UI 설정을 덮어씀). 원격 backend 호스트는 프로필(profile)별로 따로 설정되므로, 프로필을 바꾸면
> 연결된 원격 host도 같이 바뀝니다.

---

## 4. 트러블슈팅

| 증상 | 원인 / 확인 방법 |
|---|---|
| Sign-in 401 / "Invalid credentials" | `.env`의 `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`/`PASSWORD`와 불일치. `curl -s http://<host>:9119/api/status \| jq '.auth_required, .auth_providers'`로 `"basic"`이 포함되는지 확인. |
| Sign in 버튼 대신 session token 입력창 | username/password provider가 비활성 상태. `.env`에 두 값이 모두 설정됐는지, dashboard 프로세스가 그 `.env`를 로드했는지 확인. |
| 재시작할 때마다 로그아웃됨 | `HERMES_DASHBOARD_BASIC_AUTH_SECRET`을 고정값으로 설정하지 않음 → 재시작마다 서명 키가 랜덤 재생성됨. |
| Connection refused / timeout | `--host`가 여전히 `127.0.0.1`이거나, 호스트 방화벽이 9119를 막고 있음. |
| 방화벽 확인이 헷갈림 | `systemctl status firewalld` / `systemctl status iptables`가 "Unit ... could not be found"를 반환해도 방화벽이 없다는 뜻이 아닐 수 있음 — 배포판에 따라 **ufw**를 쓰기도 함 (`systemctl is-active ufw`로 확인). 이 서버(Ubuntu 20.04)는 실제로 ufw가 active 상태였음. |
| "docker에서 포트 연결만 하면 되지 않나?" | `network_mode: host`에서는 docker `-p` 포트포워딩 자체가 적용되지 않음 (compose가 `ports:`를 무시함) — 대신 앱이 bind하는 주소(`--host`)와 호스트 자체 방화벽만 신경 쓰면 됨. bridge 모드로 바꿔 `-p`를 쓰더라도 호스트 방화벽 확인은 어차피 별도로 필요함. |

---

## 5. 참고: Hermes 에이전트 자체 버전 업데이트

이 저장소는 `docker-compose.yml`이 매번 upstream GitHub 태그에서 소스를 fetch해서 빌드하는 구조라
(`context: https://github.com/NousResearch/hermes-agent.git#${HERMES_AGENT_REF}`), 컨테이너
안에서 `hermes update`를 실행해도 "published image에는 git 워킹트리가 없다"며 실패합니다. 버전을
올리려면:

```bash
# 최신 태그 확인
git ls-remote --tags --refs https://github.com/NousResearch/hermes-agent.git | awk -F/ '{print $NF}' | sort -V | tail -5

# .env에 반영
# HERMES_AGENT_REF=v2026.7.20

HERMES_UID=1003 HERMES_GID=1003 docker compose up -d --build
```

`~/.hermes`가 볼륨 마운트이므로, 이미지가 바뀌어도 설정/훅/세션 등 데이터는 그대로 유지됩니다.

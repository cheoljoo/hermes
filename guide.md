# Hermes Agent 설치 및 운영 가이드

> **대상:** Linux 계정이 있는 모든 사용자. Docker만 사용할 줄 알면 됩니다.  
> **이 저장소:** `/data01/cheoljoo.lee/code/hermes`  
> **현재 적용된 버전:** `v2026.7.1`

---

## 목차

1. [Hermes란?](#1-hermes란)
2. [사전 준비](#2-사전-준비)
3. [저장소 클론](#3-저장소-클론)
4. [환경 변수 설정 (.env)](#4-환경-변수-설정-env)
5. [빌드 및 실행](#5-빌드-및-실행)
6. [초기 설정 마법사](#6-초기-설정-마법사)
7. [Telegram 봇 연동](#7-telegram-봇-연동)
8. [EXAONE (LGE 내부 모델) 연동](#8-exaone-lge-내부-모델-연동)
9. [대시보드 접속](#9-대시보드-접속)
10. [Kanban으로 작업 관리](#10-kanban으로-작업-관리)
11. [cron 자동화](#11-cron-자동화)
12. [무료 모델 감시 스크립트](#12-무료-모델-감시-스크립트)
13. [상태 확인 및 트러블슈팅](#13-상태-확인-및-트러블슈팅)
14. [지금까지 한 일 요약](#14-지금까지-한-일-요약)

---

## 1. Hermes란?

[Nous Research](https://nousresearch.com/)가 만든 **셀프 호스팅 AI 에이전트**입니다.

- Telegram, Discord, Slack 등 메신저에서 AI에게 일을 시킬 수 있습니다.
- Kanban 보드로 작업을 관리하고 AI가 자동으로 처리합니다.
- cron으로 정기 작업(일간 리포트, 금융 데이터 수집 등)을 자동화합니다.
- 자신만의 LLM(모델)을 연결할 수 있습니다 (OpenRouter, EXAONE 등).
- 모든 데이터는 내 서버의 `~/.hermes`에 저장됩니다. 외부 서비스에 기록이 남지 않습니다.

**핵심 특징:** 클라우드 서비스가 아니라 **내 서버 위에서 직접 실행**되는 AI 비서입니다.

---

## 2. 사전 준비

### 2-1. Docker가 설치되어 있는지 확인

```bash
docker --version
# 예: Docker version 27.x.x

docker compose version
# 예: Docker Compose version v2.x.x
```

없으면 관리자에게 Docker 설치를 요청하거나 공식 문서를 참고하세요:  
https://docs.docker.com/engine/install/

### 2-2. API 키 준비

최소 1개의 LLM 제공자 키가 필요합니다.

| 옵션 | 설명 | 무료 여부 |
|------|------|----------|
| **OpenRouter** | 다양한 무료 모델 제공 (권장 시작점) | 무료 모델 있음 |
| **EXAONE (LGE 내부)** | LGE 임직원용 내부 모델 | 사내 사용 가능 |
| OpenAI | ChatGPT 계열 | 유료 |
| Anthropic | Claude 계열 | 유료 |

> **초보자 추천:** OpenRouter(https://openrouter.ai/keys)에서 가입 후 API 키 발급. 무료 모델(`google/gemma-4-31b-it:free` 등)을 사용하면 비용 없이 시작할 수 있습니다.

---

### 2-3. OpenRouter API 키 발급 방법

1. 브라우저에서 **https://openrouter.ai** 접속
2. 우측 상단 **"Sign In"** → Google / GitHub 계정으로 로그인 (또는 이메일 가입)
3. 로그인 후 우측 상단 프로필 클릭 → **"Keys"** 메뉴 선택  
   (직접 주소: https://openrouter.ai/keys)
4. **"Create Key"** 버튼 클릭
5. 키 이름 입력 (예: `hermes-home`) → **"Create"**
6. 화면에 표시된 `sk-or-v1-xxxxxxxx...` 형태의 키를 복사

> **주의:** 키는 생성 직후에만 전체 표시됩니다. 반드시 즉시 복사해서 `.env`에 붙여넣으세요.

**무료 모델 한도:**
- 무료 모델은 하루 요청 수 제한이 있습니다 (보통 200~1000 requests/day).
- 무료 모델 목록: https://openrouter.ai/models?max_price=0
- 현재 이 설치에서 사용 중인 무료 모델: `google/gemma-4-31b-it:free`

---

### 2-4. EXAONE API 키 발급 방법 (LGE 임직원 전용)

EXAONE은 LGE AILab에서 운영하는 내부 SWE API입니다.

1. 사내 포털 또는 AILab 담당자를 통해 API 키 신청
2. 발급된 키를 `.env`의 `EXAONE_API_KEY=` 에 입력
3. 엔드포인트: `http://exacode-chat.lge.com/v1` (사내 네트워크 필요)

> **참고:** 외부 인터넷에서는 `exacode-chat.lge.com`에 접근할 수 없습니다.  
> VPN 또는 사내 네트워크에 연결된 상태에서만 사용 가능합니다.

---

### 2-5. Telegram Bot Token 발급 방법

1. Telegram 앱(모바일 또는 PC)에서 검색창에 **`@BotFather`** 입력 후 접속
2. **"Start"** 버튼 클릭 또는 `/start` 전송
3. **`/newbot`** 전송
4. 봇의 **이름** 입력 (사용자에게 보이는 이름, 예: `My Hermes Bot`)
5. 봇의 **아이디(username)** 입력 (영문+숫자, 반드시 `bot`으로 끝나야 함, 예: `my_hermes_bot`)
6. BotFather가 토큰을 발급함:
   ```
   Done! Congratulations on your new bot. You will find it at t.me/my_hermes_bot.
   Use this token to access the HTTP API:
   1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ
   ```
7. 위 토큰(`1234567890:ABC...` 형태)을 복사하여 `.env`의 `TELEGRAM_BOT_TOKEN=` 에 입력

> **팁:** 봇 아이디는 전 세계적으로 유일해야 합니다. 이미 사용 중인 이름이면  
> BotFather가 "Sorry, this username is already taken."이라고 알려줍니다.  
> 이 경우 다른 이름을 시도하세요.

**내 Telegram 사용자 ID 확인 방법 (pairing에 필요):**
1. Telegram에서 **`@userinfobot`** 검색 후 `/start` 전송
2. 내 숫자 ID를 알려줌 (예: `65361116`)
3. 이 ID가 Hermes pairing 승인 후 허용 목록에 등록됨

---

## 3. 저장소 클론

```bash
# 이 저장소를 원하는 위치에 클론
git clone https://github.com/cheoljoo/hermes.git ~/code/hermes
cd ~/code/hermes
```

> **참고:** 이 저장소는 Hermes Agent 소스 코드를 직접 포함하지 않습니다.  
> `docker compose build` 시 GitHub에서 자동으로 받아와 빌드합니다.

---

## 4. 환경 변수 설정 (.env)

```bash
# 예제 파일 복사
cp .env.example .env

# 편집기로 열기
nano .env
# 또는
vi .env
```

`.env` 파일에서 최소한 다음 항목을 채우세요:

```bash
# === 필수: LLM 제공자 키 (최소 1개) ===
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxx   # OpenRouter 키

# === 선택: LGE 내부 모델 (임직원만) ===
EXAONE_API_KEY=xxxxxxxx

# === 선택: Telegram 봇 연동 ===
TELEGRAM_BOT_TOKEN=1234567890:ABCdef...

# === 자동 설정됨 (수동 입력 불필요) ===
# HERMES_UID / HERMES_GID는 아래 명령으로 자동 채워집니다
```

### UID/GID 자동 채우기 (중요!)

```bash
# .env 파일에 내 계정 UID/GID를 기록해둡니다
echo "HERMES_UID=$(id -u)" >> .env
echo "HERMES_GID=$(id -g)" >> .env
```

> **왜 필요한가?** 컨테이너 안에서 만든 파일의 소유자가 내 계정과 일치해야  
> `~/.hermes` 폴더에 저장된 파일을 읽고 쓸 수 있습니다.

---

## 5. 빌드 및 실행

```bash
# 처음 실행 시 (이미지 빌드 포함 - 5~15분 소요)
cd ~/code/hermes
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d --build
```

빌드가 완료되면:

```bash
# 컨테이너 상태 확인
docker compose ps

# 예상 출력:
# NAME                IMAGE                   STATUS
# hermes              hermes-agent:v2026.7.1  Up
# hermes-dashboard    hermes-agent:v2026.7.1  Up
```

> **이후 재시작은 빠름:** `docker compose up -d` (빌드 없이)

---

## 6. 초기 설정 마법사

컨테이너가 뜬 직후 한 번만 실행하면 됩니다.

```bash
docker compose exec -it gateway hermes setup
```

대화형 마법사가 실행됩니다:
1. LLM 제공자 선택 (예: OpenRouter)
2. 모델 선택 (무료 모델 목록 중 선택)
3. 도구 활성화 여부 (웹 검색, 파일 쓰기 등)
4. 메신저 연동 설정

설정 완료 후 확인:

```bash
docker compose exec gateway hermes status
```

---

## 7. Telegram 봇 연동

### 7-1. 봇 토큰 발급

1. Telegram에서 **@BotFather** 검색
2. `/newbot` 전송
3. 봇 이름 입력 (예: `MyHermesBot`)
4. 봇 아이디 입력 (예: `my_hermes_bot`)
5. 발급된 토큰을 `.env`의 `TELEGRAM_BOT_TOKEN=`에 입력

### 7-2. 연동 활성화

```bash
# .env에 토큰 입력 후 컨테이너 재시작
docker compose up -d gateway

# 연동 확인
docker compose exec gateway hermes status
# "Messaging Platforms → Telegram: configured" 라고 나오면 성공
```

### 7-3. 내 계정 pairing (보안 승인)

```bash
# 1. Telegram에서 내 봇에게 아무 메시지나 전송
#    예: "안녕"

# 2. 봇이 pairing 코드로 답장함 (예: PAIR-ABCD-1234)

# 3. 서버에서 승인
docker compose exec gateway hermes pairing approve telegram PAIR-ABCD-1234

# 이후부터 Telegram에서 AI에게 직접 지시 가능!
```

---

## 8. EXAONE (LGE 내부 모델) 연동

이 저장소에는 LGE AILab의 EXAONE 모델을 연결하는 플러그인이 포함되어 있습니다.

### 8-1. API 키 설정

`.env` 파일에:
```bash
EXAONE_API_KEY=여기에_EXAONE_API_키_입력
```

### 8-2. EXAONE을 기본 모델로 설정

```bash
# 컨테이너 재시작 (플러그인 마운트 반영)
docker compose up -d

# EXAONE을 기본 모델로 설정
docker compose exec gateway hermes config set model.provider exaone
docker compose exec gateway hermes config set model.default Chat-EXACODE-A
docker compose exec gateway hermes config set model.base_url http://exacode-chat.lge.com/v1

# 테스트
docker compose exec gateway hermes -z "1+1은?"
```

### 8-3. 모델 변경 (언제든지)

```bash
# 대화형 모델 선택기
docker compose exec -it gateway hermes model

# 또는 직접 지정
docker compose exec gateway hermes config set model.provider openrouter
docker compose exec gateway hermes config set model.default google/gemma-4-31b-it:free
```

---

## 9. 대시보드 접속

대시보드는 보안상 기본적으로 서버의 `localhost:9119`에서만 실행됩니다.  
**GUI 없는 Linux 서버**에서 작업 중이라면 SSH 터널을 사용합니다.

### VSCode Remote-SSH 사용 시 (가장 쉬움)

1. VSCode 하단의 **"PORTS"** 탭 클릭
2. **"Forward a Port"** → `9119` 입력 → Enter
3. 생성된 로컬 주소 클릭 → 브라우저에서 자동 열림

### 수동 SSH 터널

```bash
# 로컬 PC의 터미널에서 (서버 접속 터미널과 별도로)
ssh -L 9119:localhost:9119 사용자명@서버주소

# 이 터미널을 열어둔 채로 로컬 브라우저에서:
# http://localhost:9119
```

---

## 10. Kanban으로 작업 관리

대시보드의 **Kanban** 탭에서 AI에게 복잡한 작업을 지시할 수 있습니다.

### 티켓 만들기 (올바른 방법)

| 항목 | 값 | 이유 |
|------|----|------|
| **Assignee** | `default` | 반드시 지정해야 AI가 실행함 |
| **Triage** | **체크 해제** | 체크하면 AI가 멈춤 (별도 설정 필요) |
| **Status** | `ready` | 이 상태일 때 AI가 자동 실행 |

### 예시 티켓

```
Title: 한국 KOSPI200, KOSDAQ50, 금 지수 그래프를 그려서 Telegram에 전송해줘
Body: yfinance를 사용하고 matplotlib으로 그래프를 만들 것
      결과 이미지를 Telegram으로 보내줄 것
Assignee: default
Status: ready   (Triage 해제 필수!)
```

### 수동으로 Kanban 처리

```bash
# CLI에서 직접 ready 태스크 실행
docker compose exec gateway hermes -z "kanban에 ready 상태인 태스크를 처리해줘"
```

---

## 11. cron 자동화

Hermes 안의 cron 기능으로 정기 작업을 예약할 수 있습니다.

### 예시: 매일 오전 8시 리포트

```bash
# Hermes에게 cron 등록 지시 (Telegram이나 CLI에서)
docker compose exec gateway hermes -z \
  "매일 오전 8시에 오늘의 KOSPI, KOSDAQ 지수를 요약해서 Telegram으로 보내줘"
```

### 등록된 cron 확인

```bash
docker compose exec gateway hermes -z "등록된 cron 작업 목록을 보여줘"
```

### 현재 등록된 cron (이 설치에서 확인됨)

| ID | 스케줄 | 내용 |
|----|--------|------|
| `8646d12044bd` | 매시간 | Kanban ready 태스크 자동 처리 |

---

## 12. 무료 모델 감시 스크립트

OpenRouter의 무료 모델이 유료로 전환될 경우 자동으로 컨테이너를 중지하는 스크립트입니다.

### 파일 위치

`scripts/check_free_model.sh`

### crontab 등록 방법

```bash
# crontab 편집
crontab -e

# 다음 줄 추가 (매일 오전 8시 KST = UTC 23시 실행)
0 23 * * * /data01/cheoljoo.lee/code/hermes/scripts/check_free_model.sh

# 저장 후 확인
crontab -l | grep check_free_model
```

### 로그 확인

```bash
tail -f ~/code/hermes/scripts/check_free_model.log
```

> **참고:** EXAONE 등 OpenRouter가 아닌 provider 사용 시 이 스크립트는 자동으로 skip합니다.

---

## 13. 상태 확인 및 트러블슈팅

### 기본 상태 확인

```bash
# 컨테이너 상태
docker compose ps

# 실시간 로그
docker compose logs -f gateway

# Hermes 내부 상태 (모델, 플랫폼, API 키 등)
docker compose exec gateway hermes status

# 현재 설정 전체 보기
docker compose exec gateway hermes config show
```

### 자주 발생하는 문제

#### 1. `PermissionError` 또는 500 에러 (kanban)

```bash
# 파일 소유권 복구
docker compose exec -u root gateway chown -R $(id -u):$(id -g) /opt/data
```

#### 2. `no configuration file provided: not found`

```bash
# 반드시 docker-compose.yml이 있는 디렉터리에서 실행해야 함
cd ~/code/hermes
docker compose ps
```

#### 3. 다른 디렉터리에서 실행하고 싶을 때

```bash
docker compose -f ~/code/hermes/docker-compose.yml ps
```

#### 4. 컨테이너 재시작

```bash
docker compose restart gateway
```

#### 5. 완전 재빌드 (버전 업데이트 포함)

```bash
docker compose down
HERMES_AGENT_REF=v2026.7.1 docker compose up -d --build
```

---

## 14. 지금까지 한 일 요약

이 저장소에서 현재까지 진행된 설정 내역입니다.

### 완료된 설정

| 날짜 | 작업 내용 |
|------|----------|
| 2026-07-06 | 저장소 초기화, `docker-compose.yml` 작성, 최초 빌드 |
| 2026-07-06 | `.env` 설정 (OpenRouter, EXAONE API 키 입력) |
| 2026-07-06 | `hermes setup` 실행 - 초기 설정 완료 |
| 2026-07-06 | EXAONE 플러그인 추가 (`plugins/exaone/`) |
| 2026-07-07 | Telegram 봇 연동 완료 (`@BotFather`로 토큰 발급) |
| 2026-07-07 | `hermes pairing approve` 로 내 Telegram 계정 승인 |
| 2026-07-07 | Telegram으로 첫 대화 테스트 성공 |
| 2026-07-07 | `check_free_model.sh` 작성 및 crontab 등록 (매일 08:00 KST) |
| 2026-07-13 | Kanban에서 ready 태스크 Telegram으로 처리 요청 |
| 2026-07-14 | Kanban에 거시경제 지표 리포트 생성 작업 등록 및 실행 |
| 2026-07-14 | Kanban 자동 처리 cron 등록 (ID: `8646d12044bd`, 매시간 실행) |

### 현재 구성

- **LLM 모델:** EXAONE (기본), OpenRouter `google/gemma-4-31b-it:free` (fallback)
- **메신저:** Telegram 연동됨 (사용자 ID: `65361116`)
- **자동화:** Kanban 매시간 자동 처리 cron 활성화
- **플러그인:** `plugins/exaone/` (LGE AILab EXAONE provider)
- **데이터 저장 위치:** `~/.hermes/`

### 데이터 저장 위치

```
~/.hermes/
├── config.yaml          # 전체 설정
├── state.db             # 대화 이력, 세션 정보
├── kanban/              # Kanban 작업 DB, 로그, 출력물
├── memories/            # AI가 기억하는 나의 정보
├── sessions/            # 세션별 대화 기록
└── scripts/             # cron 스크립트 등
```

---

## 다음 단계 (할 수 있는 것들)

- [ ] Email 연동 추가 (SMTP 설정으로 AI가 이메일 보내기)
- [ ] Discord/Slack 연동 추가
- [ ] 정기 금융 데이터 수집 및 Telegram 리포트 자동화
- [ ] 개인화 스킬(Skill) 작성으로 반복 작업 자동화
- [ ] MCP 서버 연결 (외부 도구 연동)

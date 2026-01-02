# Claude Code MCP 연계 가이드

Claude Code CLI에서 MCP(Model Context Protocol)를 활용하여 외부 시스템과 연동하는 방법을 다룹니다.

---

## 목차

1. [MCP 개요](#1-mcp-개요)
   - 1.1 MCP란?
   - 1.2 2025년 11월 스펙 주요 변경사항
   - 1.3 MCP의 세 가지 핵심 기능
2. [Claude Code에서 MCP 설정](#2-claude-code에서-mcp-설정)
   - 2.1 MCP 클라이언트로서의 Claude Code
   - 2.2 설정 파일 구조
   - 2.3 프로젝트별 vs 글로벌 설정
   - 2.4 디버깅
3. [Skill + MCP 통합 패턴](#3-skill--mcp-통합-패턴)
   - 3.1 Skill에서 MCP 도구 호출
   - 3.2 여러 MCP 서버 조합
   - 3.3 실전 예시: 기술 경쟁분석 Skill
4. [Agent + MCP 통합 패턴](#4-agent--mcp-통합-패턴)
   - 4.1 전문화된 Agent에 MCP 도구 할당
   - 4.2 Agent별 MCP 서버 분리 전략
   - 4.3 실전 예시: 코드 리뷰 Agent
5. [멀티 에이전트 오케스트레이션 + MCP](#5-멀티-에이전트-오케스트레이션--mcp)
   - 5.1 Agent-MCP 프레임워크 패턴
   - 5.2 Handoff 패턴
   - 5.3 Reflection 패턴
   - 5.4 병렬 실행 패턴
6. [인기 MCP 서버 활용 가이드](#6-인기-mcp-서버-활용-가이드)
   - 6.1 GitHub MCP
   - 6.2 Database MCP
   - 6.3 AWS MCP
   - 6.4 Zapier MCP
   - 6.5 Playwright MCP
   - 6.6 Context7
7. [보안 Best Practices](#7-보안-best-practices)
   - 7.1 자격 증명 관리
   - 7.2 환경 분리
   - 7.3 읽기 전용 우선 원칙
   - 7.4 SSO 및 RBAC 통합
   - 7.5 2025년 보안 이슈 및 대응
8. [Hook + MCP 연계](#8-hook--mcp-연계)
   - 8.1 MCP 도구 호출 전/후 Hook
   - 8.2 MCP 결과 검증 Hook
   - 8.3 자격 증명 자동 주입 패턴
9. [실전 워크플로우 예시](#9-실전-워크플로우-예시)
   - 9.1 기본: GitHub PR 자동 리뷰
   - 9.2 중급: 멀티소스 경쟁분석 파이프라인
   - 9.3 고급: 풀스택 배포 오케스트레이션

---

## 1. MCP 개요

### 1.1 MCP란?

**Model Context Protocol (MCP)**은 Anthropic이 2024년 11월 발표한 오픈 표준으로, AI 시스템이 외부 도구, 데이터 소스, 시스템과 표준화된 방식으로 연결할 수 있게 해줍니다.

```
┌─────────────────┐     MCP      ┌─────────────────┐
│   Claude Code   │◄────────────►│   MCP Server    │
│   (MCP Client)  │              │  (GitHub, DB..) │
└─────────────────┘              └─────────────────┘
```

**핵심 가치:**
- **표준화**: 각 서비스마다 다른 API 대신 통일된 프로토콜
- **보안**: 자격 증명이 클라이언트를 거치지 않는 안전한 연결
- **확장성**: 플러그인처럼 MCP 서버 추가/제거 가능

**2025년 현황:**
- 2025년 3월 OpenAI 공식 채택
- 2025년 12월 Linux Foundation 산하 Agentic AI Foundation에 기증
- "AI 모델에 컨텍스트를 제공하는 사실상의 표준"으로 자리잡음

### 1.2 2025년 11월 스펙 주요 변경사항

MCP 1주년 스펙 릴리즈의 핵심 변경:

| 기능 | 설명 |
|------|------|
| **Server-side Agent Loops** | MCP 서버 내에서 다단계 추론 가능 |
| **Parallel Tool Calls** | 여러 도구를 동시에 호출하여 성능 향상 |
| **Tool Calling in Sampling** | 샘플링 요청 내에서 도구 호출 지원 |
| **Better Context Control** | 컨텍스트 관리 세밀화 |
| **Secure Credential Collection** | API 키가 클라이언트를 거치지 않는 보안 연결 |
| **External OAuth Flows** | 외부 OAuth 인증 지원 |

### 1.3 MCP의 세 가지 핵심 기능

```
┌───────────────────────────────────────────────────────────┐
│                        MCP Server                         │
├───────────────────┬───────────────────┬───────────────────┤
│     Resources     │       Tools       │      Prompts      │
│    (읽기 전용)    │   (능동적 실행)   │     (템플릿)      │
├───────────────────┼───────────────────┼───────────────────┤
│  파일, DB 조회    │  API 호출, 생성   │   사전 정의된     │
│  웹 콘텐츠 등     │  수정, 삭제 등    │  프롬프트 템플릿  │
└───────────────────┴───────────────────┴───────────────────┘
```

**Resources** (자원):
- 읽기 전용 데이터
- 파일, 데이터베이스 엔트리, 웹 콘텐츠
- 예: Google Drive 문서 조회

**Tools** (도구):
- 능동적 액션/함수
- 데이터 생성, 수정, 삭제 가능
- 예: GitHub PR 생성, Slack 메시지 전송

**Prompts** (프롬프트):
- 특정 작업을 위한 사전 정의 템플릿
- 예: "코드 리뷰 요청" 프롬프트

---

## 2. Claude Code에서 MCP 설정

### 2.1 MCP 클라이언트로서의 Claude Code

Claude Code는 **MCP 클라이언트이자 서버**로 동작:
- **클라이언트**: 외부 MCP 서버에 연결하여 도구 사용
- **서버**: 다른 클라이언트에 도구 제공 가능

```
┌──────────────────────────────────────────────────────────┐
│                      Claude Code                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │                   MCP Client                        ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐            ││
│  │  │ GitHub  │  │   DB    │  │   AWS   │  ...       ││
│  │  │  MCP    │  │   MCP   │  │   MCP   │            ││
│  │  └────┬────┘  └────┬────┘  └────┬────┘            ││
│  └───────┼────────────┼────────────┼─────────────────┘│
└──────────┼────────────┼────────────┼──────────────────┘
           ▼            ▼            ▼
      GitHub API   PostgreSQL    AWS Services
```

### 2.2 설정 파일 구조

**`.claude/settings.json` 또는 `~/.claude/settings.json`:**

```jsonc
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"]
    }
  }
}
```

**설정 항목:**

| 항목 | 설명 |
|------|------|
| `command` | MCP 서버 실행 명령어 |
| `args` | 명령어 인자 |
| `env` | 환경 변수 (토큰, 비밀번호 등) |

### 2.3 프로젝트별 vs 글로벌 설정

| 위치 | 범위 | 용도 |
|------|------|------|
| `.claude/settings.json` | 프로젝트 | 프로젝트별 MCP 서버 |
| `~/.claude/settings.json` | 글로벌 | 모든 프로젝트에서 공통 사용 |

**우선순위**: 프로젝트 설정 > 글로벌 설정

**권장 패턴:**
```
글로벌: 공통 도구 (GitHub, Slack)
프로젝트: 프로젝트 특화 DB, 특정 API
```

### 2.4 CLI로 MCP 서버 관리

설정 파일을 직접 편집하는 대신 `claude mcp` 명령어로 관리할 수 있습니다.

**기본 명령어:**

```bash
# MCP 서버 목록 확인
claude mcp list

# MCP 서버 추가
claude mcp add <서버이름> -- <실행명령어>

# MCP 서버 제거
claude mcp remove <서버이름>
```

**예시: GitHub MCP 추가**

```bash
claude mcp add github -- npx -y @modelcontextprotocol/server-github
```

**예시: Codex 리뷰 서버 추가 (옵션 포함)**

```bash
claude mcp add codex-review -- codex mcp -c model="gpt-5.2-codex" -c model_reasoning_effort="high"
```

**명령어 구조 이해:**

```
claude mcp add <이름> -- <명령어 전체>
                      ^^
                      옵션 종료 표시
```

- `--` 앞: `claude mcp add`의 옵션
- `--` 뒤: MCP 서버로 실행할 명령어 (그대로 저장됨)
- `-c`, `--config`: 실행 명령어에 전달되는 옵션 (축약형/풀네임)

**설정 저장 위치:**

| 범위 | 파일 위치 |
|------|----------|
| 프로젝트 (기본) | `~/.claude.json` (프로젝트 섹션) |
| 글로벌 | `claude mcp add --global` 사용 시 |

### 2.5 디버깅

```bash
# MCP 디버그 모드로 Claude Code 실행
claude --mcp-debug

# 디버그 출력 예시
[MCP Debug] Connecting to server: github
[MCP Debug] Available tools: create_issue, list_repos, ...
[MCP Debug] Tool call: create_issue
[MCP Debug] Response received in 234ms
```

**트러블슈팅:**

| 문제 | 해결 |
|------|------|
| 서버 연결 실패 | 환경 변수 확인, 네트워크 확인 |
| 도구 목록 비어있음 | MCP 서버 버전 확인, 재시작 |
| 인증 오류 | 토큰 만료 확인, 권한 확인 |

---

## 3. Skill + MCP 통합 패턴

### 3.1 Skill에서 MCP 도구 호출

Skill은 MCP 서버가 제공하는 도구를 직접 호출할 수 있습니다.

**`.claude/skills/github-assistant/SKILL.md`:**
```yaml
---
name: github-assistant
description: GitHub 저장소 관리 도우미
allowed-tools: Read, Write, Task
# MCP 도구는 allowed-tools에 명시하지 않아도 사용 가능
# 시스템이 자동으로 MCP 서버의 도구를 인식
---

# GitHub 저장소 관리

당신은 GitHub 관리 전문가입니다.

## 사용 가능한 MCP 도구

- `github_create_issue`: 이슈 생성
- `github_list_repos`: 저장소 목록
- `github_create_pr`: PR 생성
- `github_get_file_contents`: 파일 내용 조회

## 작업 흐름

1. 사용자 요청 분석
2. 적절한 MCP 도구 선택
3. 결과 정리하여 보고
```

### 3.2 여러 MCP 서버 조합

하나의 Skill에서 여러 MCP 서버를 조합하여 강력한 워크플로우 구축:

```
┌─────────────────────────────────────────────────┐
│              Multi-Source Skill                 │
│                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ GitHub  │  │ Google  │  │  Slack  │        │
│  │   MCP   │  │  Drive  │  │   MCP   │        │
│  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │              │
│       └────────────┼────────────┘              │
│                    ▼                           │
│             결과 통합 및 보고                    │
└─────────────────────────────────────────────────┘
```

**`.claude/skills/research-assistant/SKILL.md`:**
```yaml
---
name: research-assistant
description: 여러 소스에서 정보를 수집하여 리서치
allowed-tools: Read, Write, Task
---

# 멀티소스 리서치 어시스턴트

## MCP 서버 활용

### 1. 내부 문서 검색 (Google Drive MCP)
- `gdrive_search`: 키워드로 문서 검색
- `gdrive_read`: 문서 내용 읽기

### 2. 코드 저장소 분석 (GitHub MCP)
- `github_search_code`: 코드 검색
- `github_get_file_contents`: 파일 내용 조회

### 3. 결과 공유 (Slack MCP)
- `slack_post_message`: 채널에 결과 게시

## 워크플로우

1. Google Drive에서 관련 문서 검색
2. GitHub에서 관련 코드 찾기
3. 결과 종합하여 Slack으로 보고
```

### 3.3 실전 예시: 기술 경쟁분석 Skill

**프로젝트 구조:**
```
.claude/
├── settings.json          # MCP 서버 설정
└── skills/
    └── competitive-analysis/
        └── SKILL.md
```

**settings.json:**
```jsonc
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "gdrive": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-gdrive"],
      "env": {
        "GOOGLE_CREDENTIALS": "${GOOGLE_CREDENTIALS}"
      }
    }
  }
}
```

**SKILL.md:**
```yaml
---
name: competitive-analysis
description: 경쟁사 기술 분석 리포트 생성
allowed-tools: Read, Write, WebSearch
---

# 경쟁사 기술 분석

당신은 기술 분석 전문가입니다.

## 분석 프로세스

### Phase 1: 내부 자료 수집
1. Google Drive에서 기존 경쟁분석 문서 검색
2. 관련 내부 리서치 자료 확인

### Phase 2: 외부 정보 수집
1. GitHub에서 경쟁사 오픈소스 프로젝트 분석
2. 웹 검색으로 최신 뉴스/발표 확인

### Phase 3: 리포트 생성
1. 수집된 정보 종합
2. SWOT 분석 작성
3. 마크다운 리포트 생성

## 출력 형식

```markdown
# 경쟁사 분석 리포트: [회사명]

## 요약
...

## 기술 스택
...

## 오픈소스 활동
...

## SWOT 분석
...

## 결론 및 시사점
...
```

## MCP 도구 활용

- `gdrive_search`: 내부 문서 검색
- `github_search_repos`: 경쟁사 저장소 찾기
- `github_list_commits`: 최근 개발 활동 분석
```

---

## 4. Agent + MCP 통합 패턴

### 4.1 전문화된 Agent에 MCP 도구 할당

각 Agent에 필요한 MCP 도구만 명시하여 역할을 명확히 분리:

```
┌─────────────────────────────────────────────────────────────┐
│                   Skill (오케스트레이터)                    │
│                                                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  │
│  │   DB Agent    │  │ GitHub Agent  │  │ Report Agent  │  │
│  │               │  │               │  │               │  │
│  │  postgres_*   │  │   github_*    │  │   gdrive_*    │  │
│  │  도구만 사용  │  │  도구만 사용  │  │  도구만 사용  │  │
│  └───────────────┘  └───────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**`.claude/agents/db-analyst/db-analyst.md`:**
```markdown
---
name: db-analyst
description: 데이터베이스 분석 전문 Agent
tools: Read
---

# Database Analyst Agent

당신은 데이터베이스 분석 전문가입니다.

## 사용 가능한 MCP 도구

- `postgres_query`: SQL 쿼리 실행 (읽기 전용)
- `postgres_list_tables`: 테이블 목록 조회
- `postgres_describe_table`: 테이블 스키마 조회

## 분석 원칙

1. **읽기 전용**: SELECT 쿼리만 실행
2. **성능 고려**: LIMIT 사용, 인덱스 활용
3. **보안**: 민감 데이터 마스킹

## 출력 형식

```json
{
  "agent": "db-analyst",
  "query": "실행한 쿼리",
  "results": [...],
  "insights": "분석 결과 요약"
}
```
```

### 4.2 Agent별 MCP 서버 분리 전략

**권장 패턴: 역할 기반 분리**

| Agent 역할 | MCP 서버 | 권한 |
|-----------|---------|------|
| Code Analyst | GitHub MCP | 읽기 전용 |
| DB Analyst | PostgreSQL MCP | SELECT만 |
| Deployer | AWS MCP | 제한된 쓰기 |
| Reporter | Google Drive MCP | 문서 생성 |

**보안을 위한 분리:**
```jsonc
{
  "mcpServers": {
    // 읽기 전용 DB 연결 (분석용)
    "postgres-readonly": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL_READONLY}"
      }
    },
    // 쓰기 가능 DB 연결 (운영용)
    "postgres-admin": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL_ADMIN}"
      }
    }
  }
}
```

### 4.3 실전 예시: 코드 리뷰 Agent

**`.claude/agents/code-reviewer/code-reviewer.md`:**
```markdown
---
name: code-reviewer
description: GitHub PR 코드 리뷰 Agent
tools: Read, Grep
---

# Code Reviewer Agent

당신은 시니어 개발자로서 PR을 리뷰합니다.

## MCP 도구 활용

### 정보 수집
- `github_get_pull_request`: PR 정보 조회
- `github_list_pull_request_files`: 변경된 파일 목록
- `github_get_file_contents`: 파일 내용 조회

### 리뷰 작성
- `github_create_review_comment`: 라인별 코멘트
- `github_create_pull_request_review`: 전체 리뷰 제출

## 리뷰 체크리스트

1. **코드 품질**
   - 가독성
   - 중복 코드
   - 복잡도

2. **버그 가능성**
   - null 체크
   - 에러 처리
   - 경계 조건

3. **보안**
   - 인증/인가
   - 입력 검증
   - 민감 데이터

4. **테스트**
   - 테스트 커버리지
   - 엣지 케이스

## 출력 형식

```json
{
  "agent": "code-reviewer",
  "pr_number": 123,
  "verdict": "APPROVE|REQUEST_CHANGES|COMMENT",
  "summary": "전체 요약",
  "comments": [
    {
      "file": "src/app.js",
      "line": 42,
      "severity": "high",
      "message": "코멘트 내용"
    }
  ]
}
```
```

---

## 5. 멀티 에이전트 오케스트레이션 + MCP

### 5.1 Agent-MCP 프레임워크 패턴

2025년 등장한 Agent-MCP 프레임워크의 핵심 원칙:

**Short-lived, Focused Agents:**
```
┌───────────────────────────────────────────────────────────┐
│                      전통적 Agent                         │
│   - 긴 수명, 전체 컨텍스트 보유                           │
│   - 보안 위험: 조작 시 전체 정보 노출                     │
└───────────────────────────────────────────────────────────┘
                           ▼
┌───────────────────────────────────────────────────────────┐
│                    Agent-MCP 패턴                         │
│   - 짧은 수명, 작업별 포커스                              │
│   - 보안: 제한된 컨텍스트만 보유                          │
│   - Fast, Focused, Safe                                  │
└───────────────────────────────────────────────────────────┘
```

**구현 예시:**
```yaml
---
name: secure-pipeline
description: 보안 중심 멀티에이전트 파이프라인
allowed-tools: Task
---

# 보안 파이프라인

## Agent 수명 관리

각 Agent는 단일 작업만 수행하고 종료:

1. **Data Fetcher Agent** (수명: ~10초)
   - DB에서 필요한 데이터만 조회
   - 결과 반환 후 즉시 종료

2. **Analyzer Agent** (수명: ~30초)
   - 전달받은 데이터 분석
   - 전체 DB 접근 권한 없음

3. **Reporter Agent** (수명: ~10초)
   - 분석 결과만 받아서 리포트 생성
   - 원본 데이터 접근 불가
```

### 5.2 Handoff 패턴

Agent 간 MCP 컨텍스트를 안전하게 전달:

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Agent A    │         │  Agent B    │         │  Agent C    │
│ (GitHub MCP)│───────►│ (분석만)     │───────►│(Slack MCP)  │
│             │ 결과만  │             │ 결과만  │             │
│ PR 정보 조회 │ 전달    │ 코드 분석   │ 전달    │ 결과 공유   │
└─────────────┘         └─────────────┘         └─────────────┘
```

**Skill에서 Handoff 구현:**
```yaml
---
name: handoff-pipeline
description: Agent 간 결과 전달 파이프라인
allowed-tools: Task, Read, Write
---

# Handoff 파이프라인

## 단계별 실행

### Step 1: GitHub Agent
```
[PHASE:FETCH]
GitHub Agent를 호출하여 PR #{{pr_number}} 정보를 조회합니다.
결과를 .claude/temp/pr_data.json에 저장하세요.
```

### Step 2: Analysis Agent
```
[PHASE:ANALYZE]
.claude/temp/pr_data.json을 읽고 분석합니다.
GitHub에 직접 접근하지 마세요 - 파일만 사용하세요.
결과를 .claude/temp/analysis.json에 저장하세요.
```

### Step 3: Notification Agent
```
[PHASE:NOTIFY]
.claude/temp/analysis.json을 읽고 Slack으로 공유합니다.
원본 코드나 PR 데이터에 접근하지 마세요.
```
```

### 5.3 Reflection 패턴

MCP 결과를 검증하고 개선하는 패턴:

```
┌───────────────────────────────────────────────────────────┐
│                     Reflection Loop                       │
│                                                           │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐        │
│  │  Action   │───►│  Review   │───►│  Refine   │        │
│  │   Agent   │    │   Agent   │    │   Agent   │        │
│  │           │    │           │    │           │        │
│  │  MCP로    │    │   결과    │    │  개선된   │        │
│  │  작업수행 │◄───│   검증    │◄───│   결과    │        │
│  └───────────┘실패└───────────┘필요└───────────┘        │
│        │                                  │              │
│        └──────────────────────────────────┘              │
│                     재시도 (최대 3회)                     │
└───────────────────────────────────────────────────────────┘
```

**Hook으로 Reflection 제어:**
```javascript
// .claude/scripts/mcp-reflection.js
const { getState, saveState, getHookOutput } = require('./utils');

const output = getHookOutput();
const state = getState();

// MCP 결과 검증
let result;
try {
  result = JSON.parse(output);
} catch (e) {
  result = { status: 'error', error: 'Invalid JSON' };
}

// 품질 검증
if (result.status === 'error' || result.score < 70) {
  if (state.reflectionCount < 3) {
    state.reflectionCount = (state.reflectionCount || 0) + 1;
    state.needsRefinement = true;
    state.lastFeedback = result.error || '품질 기준 미달';
    saveState(state);
    console.log(`Reflection ${state.reflectionCount}/3: 개선 필요`);
    process.exit(1);  // 재시도 유도
  }
}

// 성공
state.reflectionCount = 0;
state.needsRefinement = false;
saveState(state);
process.exit(0);
```

### 5.4 병렬 실행 패턴

2025년 11월 스펙의 Parallel Tool Calls 활용:

```
┌───────────────────────────────────────────────────────────┐
│                    Parallel Execution                     │
│                                                           │
│          ┌─────────────────────────────┐                 │
│          │     Orchestrator Skill      │                 │
│          └─────────────┬───────────────┘                 │
│                        │                                 │
│       ┌────────────────┼────────────────┐                │
│       │                │                │                │
│       ▼                ▼                ▼                │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐           │
│  │ Agent A │     │ Agent B │     │ Agent C │           │
│  │ GitHub  │     │ DB MCP  │     │  Slack  │           │
│  │   MCP   │     │         │     │   MCP   │           │
│  └────┬────┘     └────┬────┘     └────┬────┘           │
│       │               │               │                 │
│       └───────────────┼───────────────┘                 │
│                       ▼                                 │
│               결과 종합 및 처리                          │
└───────────────────────────────────────────────────────────┘
```

**Skill에서 병렬 실행:**
```yaml
---
name: parallel-analysis
description: 병렬로 여러 소스 분석
allowed-tools: Task
---

# 병렬 분석 파이프라인

## 동시 실행

다음 Agent들을 **병렬로** 실행하세요:

1. **GitHub Agent**: PR 변경사항 분석
2. **DB Agent**: 관련 데이터 조회
3. **Docs Agent**: 문서 검색

## 중요
- Task 도구를 한 번에 여러 개 호출하여 병렬 실행
- 각 Agent는 독립적으로 작동
- 모든 결과가 도착하면 종합 분석 수행
```

---

## 6. 인기 MCP 서버 활용 가이드

### 6.1 GitHub MCP

**설치 및 설정:**
```jsonc
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**주요 도구:**

| 도구 | 설명 |
|------|------|
| `github_create_issue` | 이슈 생성 |
| `github_list_issues` | 이슈 목록 조회 |
| `github_create_pull_request` | PR 생성 |
| `github_get_pull_request` | PR 정보 조회 |
| `github_list_pull_request_files` | PR 변경 파일 |
| `github_create_review_comment` | 리뷰 코멘트 |
| `github_search_repositories` | 저장소 검색 |
| `github_get_file_contents` | 파일 내용 조회 |

**활용 시나리오:**
- PR 자동 리뷰
- 이슈 트리아지
- 저장소 분석
- CI/CD 트리거

### 6.2 Database MCP

**PostgreSQL 설정:**
```jsonc
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://user:pass@host:5432/db"
      }
    }
  }
}
```

**Supabase 설정:**
```jsonc
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server"],
      "env": {
        "SUPABASE_URL": "${SUPABASE_URL}",
        "SUPABASE_KEY": "${SUPABASE_KEY}"
      }
    }
  }
}
```

**주요 도구:**

| 도구 | 설명 |
|------|------|
| `postgres_query` | SQL 쿼리 실행 |
| `postgres_list_tables` | 테이블 목록 |
| `postgres_describe_table` | 스키마 조회 |
| `supabase_create_table` | 테이블 생성 |
| `supabase_deploy_edge_function` | Edge Function 배포 |

**보안 권장사항:**
```jsonc
// 읽기 전용 연결 (분석용)
"DATABASE_URL": "postgresql://readonly_user:pass@host:5432/db"

// 쓰기는 별도 서버로 분리
"DATABASE_URL_ADMIN": "postgresql://admin:pass@host:5432/db"
```

### 6.3 AWS MCP

**설정:**
```jsonc
{
  "mcpServers": {
    "aws": {
      "command": "npx",
      "args": ["-y", "@aws/mcp-server-aws"],
      "env": {
        "AWS_ACCESS_KEY_ID": "${AWS_ACCESS_KEY_ID}",
        "AWS_SECRET_ACCESS_KEY": "${AWS_SECRET_ACCESS_KEY}",
        "AWS_REGION": "us-east-1"
      }
    }
  }
}
```

**주요 도구 영역:**
- **CDK/CloudFormation**: 인프라 프로비저닝
- **S3**: 파일 저장/조회
- **Lambda**: 서버리스 함수 관리
- **Bedrock**: AI/ML 서비스
- **Rekognition**: 이미지 분석

### 6.4 Zapier MCP

수천 개의 앱을 하나의 MCP 서버로 연결:

**설정:**
```jsonc
{
  "mcpServers": {
    "zapier": {
      "command": "npx",
      "args": ["-y", "@zapier/mcp-server"],
      "env": {
        "ZAPIER_API_KEY": "${ZAPIER_API_KEY}"
      }
    }
  }
}
```

**연동 가능 앱:**
- Gmail, Outlook
- Slack, Discord, Teams
- Notion, Airtable
- Salesforce, HubSpot
- Google Sheets, Excel
- 5,000+ 앱

### 6.5 Playwright MCP

UI 테스팅 자동화:

**설정:**
```jsonc
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "playwright-mcp"]
    }
  }
}
```

**주요 도구:**

| 도구 | 설명 |
|------|------|
| `playwright_navigate` | 페이지 이동 |
| `playwright_click` | 요소 클릭 |
| `playwright_fill` | 입력 필드 작성 |
| `playwright_screenshot` | 스크린샷 캡처 |
| `playwright_evaluate` | JavaScript 실행 |

**활용 시나리오:**
- E2E 테스트 실행
- 웹 스크래핑
- UI 검증

### 6.6 Context7

최신 문서와 코드 예시를 AI에 제공:

**설정:**
```jsonc
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

**특징:**
- 최신 버전별 문서 제공
- 코드 예시 포함
- AI 코드 생성 정확도 향상

**지원 기술:**
- React, Vue, Angular
- Node.js, Python, Go
- AWS, GCP, Azure 문서
- 오픈소스 라이브러리

---

## 7. 보안 Best Practices

### 7.1 자격 증명 관리

**환경 변수 사용 (필수):**
```jsonc
// 올바른 예시
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"  // 환경변수 참조
      }
    }
  }
}

// 잘못된 예시 - 절대 하지 마세요!
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_TOKEN": "ghp_xxxxxxxxxxxx"  // 하드코딩 금지!
      }
    }
  }
}
```

**OS 키체인 활용:**
```bash
# macOS
security add-generic-password -s "github-token" -a "claude" -w "ghp_xxx"

# Windows (PowerShell)
[System.Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_xxx", "User")
```

### 7.2 환경 분리

```
┌───────────────────────────────────────────────────────────┐
│                     환경별 MCP 서버                       │
├───────────────────┬───────────────────┬───────────────────┤
│    Development    │      Staging      │    Production     │
├───────────────────┼───────────────────┼───────────────────┤
│ DB: 테스트 데이터 │ DB: 복제본        │ DB: 읽기 전용     │
│ API: 샌드박스     │ API: 스테이징     │ API: 제한된 권한  │
│ 로깅: 상세        │ 로깅: 보통        │ 로깅: 최소        │
└───────────────────┴───────────────────┴───────────────────┘
```

**환경별 설정 파일:**
```bash
.claude/
├── settings.json              # 기본 (개발)
├── settings.staging.json      # 스테이징
└── settings.production.json   # 프로덕션
```

### 7.3 읽기 전용 우선 원칙

```
┌─────────────────────────────────────────────────────────┐
│                    권한 계층 구조                        │
├─────────────────────────────────────────────────────────┤
│ Level 1: 읽기 전용 (기본)                               │
│   - SELECT 쿼리만                                       │
│   - 파일 조회만                                         │
│   - API GET 요청만                                      │
├─────────────────────────────────────────────────────────┤
│ Level 2: 제한된 쓰기 (승인 필요)                        │
│   - 특정 테이블만 INSERT/UPDATE                         │
│   - 지정된 디렉토리만 쓰기                              │
│   - Feature Flag 뒤에 숨기기                            │
├─────────────────────────────────────────────────────────┤
│ Level 3: 관리자 (인간 감독 필수)                        │
│   - DELETE, DROP                                        │
│   - 프로덕션 배포                                       │
│   - 인프라 변경                                         │
└─────────────────────────────────────────────────────────┘
```

### 7.4 SSO 및 RBAC 통합

**엔터프라이즈 환경:**

| 기능 | 설명 |
|------|------|
| SSO 통합 | 기업 IdP와 연동하여 개별 API 키 제거 |
| RBAC | 역할 기반 MCP 서버 접근 제어 |
| 감사 로그 | 모든 MCP 호출 기록 |
| 세션 관리 | 토큰 만료 및 갱신 자동화 |

### 7.5 2025년 보안 이슈 및 대응

**Knostic 연구 결과 (2025년 7월):**
- 약 2,000개의 공개 MCP 서버 스캔
- 검증된 서버 중 **100%가 인증 미적용**
- 내부 도구 목록 및 민감 데이터 노출 위험

**대응 방안:**

| 위험 | 대응 |
|------|------|
| 인증 없는 MCP 서버 | 내부망에서만 운영, VPN 필수 |
| 자격 증명 노출 | 환경 변수, 키체인 사용 |
| 과도한 권한 | 최소 권한 원칙 적용 |
| 감사 부재 | 모든 MCP 호출 로깅 |

**보안 체크리스트:**
```markdown
□ 모든 자격 증명이 환경 변수로 관리되는가?
□ MCP 서버가 내부망/VPN 뒤에 있는가?
□ 읽기 전용이 기본 설정인가?
□ 쓰기 작업은 승인 프로세스가 있는가?
□ MCP 호출 로그를 보관하는가?
□ 정기적인 토큰 로테이션이 있는가?
```

---

## 8. Hook + MCP 연계

### 8.1 MCP 도구 호출 전/후 Hook

MCP 도구 호출을 Hook으로 제어:

**settings.json:**
```jsonc
{
  "hooks": {
    "preToolUse": [
      {
        "matcher": "github_*",
        "command": "node .claude/scripts/mcp-pre-check.js"
      },
      {
        "matcher": "postgres_*",
        "command": "node .claude/scripts/db-pre-check.js"
      }
    ],
    "postToolUse": [
      {
        "matcher": "github_*",
        "command": "node .claude/scripts/mcp-post-log.js"
      }
    ]
  },
  "mcpServers": {
    "github": { ... },
    "postgres": { ... }
  }
}
```

**mcp-pre-check.js:**
```javascript
// .claude/scripts/mcp-pre-check.js
const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const toolName = process.env.CLAUDE_TOOL_NAME || '';

// 위험한 작업 차단
const dangerousTools = [
  'github_delete_repository',
  'github_delete_branch'
];

if (dangerousTools.includes(toolName)) {
  console.error(`차단: ${toolName}은 허용되지 않습니다.`);
  process.exit(1);
}

// 특정 저장소 보호
if (toolName.startsWith('github_') && input.repo === 'production-critical') {
  console.error('차단: production-critical 저장소는 보호됩니다.');
  process.exit(1);
}

console.log(`허용: ${toolName}`);
process.exit(0);
```

### 8.2 MCP 결과 검증 Hook

**mcp-post-validate.js:**
```javascript
// .claude/scripts/mcp-post-validate.js
const output = process.env.CLAUDE_TOOL_OUTPUT || '';
const toolName = process.env.CLAUDE_TOOL_NAME || '';

// DB 쿼리 결과 검증
if (toolName.startsWith('postgres_')) {
  try {
    const result = JSON.parse(output);

    // 너무 많은 행 경고
    if (result.rows && result.rows.length > 1000) {
      console.warn(`경고: ${result.rows.length}개 행 반환됨. LIMIT 사용 권장.`);
    }

    // 민감 데이터 마스킹 확인
    const sensitiveFields = ['password', 'ssn', 'credit_card'];
    const hasSensitive = sensitiveFields.some(field =>
      output.toLowerCase().includes(field)
    );

    if (hasSensitive) {
      console.error('차단: 민감 데이터 포함됨');
      process.exit(1);
    }
  } catch (e) {
    // JSON 파싱 실패는 무시
  }
}

process.exit(0);
```

### 8.3 자격 증명 자동 주입 패턴

환경별로 다른 자격 증명을 사용해야 할 때 preToolUse Hook에서 환경 변수를 검증:

**credential-validator.js:**
```javascript
// .claude/scripts/credential-validator.js
const toolName = process.env.CLAUDE_TOOL_NAME || '';

// 현재 환경 감지
const env = process.env.CLAUDE_ENV || 'dev';

// 환경별 필수 자격 증명 검증
const requiredCredentials = {
  'github_*': {
    dev: 'GITHUB_TOKEN_DEV',
    staging: 'GITHUB_TOKEN_STAGING',
    prod: 'GITHUB_TOKEN_PROD'
  },
  'postgres_*': {
    dev: 'DATABASE_URL_DEV',
    staging: 'DATABASE_URL_STAGING',
    prod: 'DATABASE_URL_PROD'
  }
};

// 도구별 필수 자격 증명 확인
function checkCredential(tool, environment) {
  for (const [pattern, envVars] of Object.entries(requiredCredentials)) {
    const regex = new RegExp('^' + pattern.replace('*', '.*') + '$');
    if (regex.test(tool)) {
      const requiredVar = envVars[environment];
      if (requiredVar && !process.env[requiredVar]) {
        console.error(`오류: ${environment} 환경에서 ${requiredVar} 환경변수가 필요합니다.`);
        process.exit(1);
      }
      console.log(`[Credential] ${environment} 환경, ${tool}: ${requiredVar} 확인됨`);
      return;
    }
  }
}

checkCredential(toolName, env);
process.exit(0);
```

**환경별 설정 패턴:**
```bash
# 개발 환경
export CLAUDE_ENV=dev
export GITHUB_TOKEN_DEV=ghp_dev_xxx
export DATABASE_URL_DEV=postgresql://dev:pass@localhost/dev

# 프로덕션 환경
export CLAUDE_ENV=prod
export GITHUB_TOKEN_PROD=ghp_prod_xxx
export DATABASE_URL_PROD=postgresql://readonly:pass@prod-db/main
```

---

## 9. 실전 워크플로우 예시

### 9.1 기본: GitHub PR 자동 리뷰

**목표**: PR이 열리면 자동으로 코드 리뷰 수행

**프로젝트 구조:**
```
.claude/
├── settings.json
├── skills/
│   └── pr-reviewer/
│       └── SKILL.md
└── scripts/
    └── review-validator.js
```

**settings.json:**
```jsonc
{
  "hooks": {
    "postToolUse": [{
      "matcher": "github_*",
      "command": "node .claude/scripts/review-validator.js"
    }]
  },
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**SKILL.md:**
```yaml
---
name: pr-reviewer
description: GitHub PR 자동 리뷰
allowed-tools: Read
---

# PR 자동 리뷰어

## 프로세스

### 1. PR 정보 수집
`github_get_pull_request`로 PR 상세 정보 조회

### 2. 변경 파일 분석
`github_list_pull_request_files`로 변경된 파일 목록 확인

### 3. 코드 리뷰
각 파일에 대해:
- `github_get_file_contents`로 내용 조회
- 코드 품질, 버그, 보안 검토

### 4. 리뷰 제출
`github_create_pull_request_review`로 리뷰 제출
- APPROVE: 문제 없음
- REQUEST_CHANGES: 수정 필요
- COMMENT: 의견만

## 리뷰 기준

1. 코드 스타일 일관성
2. 잠재적 버그
3. 보안 취약점
4. 테스트 커버리지
5. 문서화
```

**review-validator.js:**
```javascript
// .claude/scripts/review-validator.js
const toolName = process.env.CLAUDE_TOOL_NAME || '';
const output = process.env.CLAUDE_TOOL_OUTPUT || '';

// github_create_pull_request_review 결과만 검증
if (toolName !== 'github_create_pull_request_review') {
  process.exit(0);
}

try {
  const result = JSON.parse(output);

  // 리뷰가 성공적으로 제출되었는지 확인
  if (result.state) {
    console.log(`리뷰 제출 완료: ${result.state}`);

    // REQUEST_CHANGES인 경우 로깅
    if (result.state === 'REQUEST_CHANGES') {
      console.log('수정 요청 리뷰가 제출되었습니다.');
    }
  }
} catch (e) {
  console.error('리뷰 결과 파싱 실패');
}

process.exit(0);
```

### 9.2 중급: 멀티소스 경쟁분석 파이프라인

**목표**: 여러 소스에서 정보를 수집하여 경쟁분석 리포트 생성

**프로젝트 구조:**
```
.claude/
├── settings.json
├── skills/
│   └── competitive-intel/
│       └── SKILL.md
├── agents/
│   ├── github-analyzer/
│   │   └── github-analyzer.md
│   ├── doc-searcher/
│   │   └── doc-searcher.md
│   └── reporter/
│       └── reporter.md
└── scripts/
    ├── pipeline-controller.js
    └── utils.js
```

**settings.json:**
```jsonc
{
  "hooks": {
    "postToolUse": [{
      "matcher": "Task",
      "command": "node .claude/scripts/pipeline-controller.js"
    }]
  },
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "gdrive": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-gdrive"],
      "env": { "GOOGLE_CREDENTIALS": "${GOOGLE_CREDENTIALS}" }
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-slack"],
      "env": { "SLACK_TOKEN": "${SLACK_TOKEN}" }
    }
  }
}
```

**SKILL.md:**
```yaml
---
name: competitive-intel
description: 경쟁사 인텔리전스 수집 및 리포트
allowed-tools: Task, Read, Write
---

# 경쟁사 인텔리전스 파이프라인

## Phase 1: 병렬 정보 수집

다음 Agent들을 **병렬로** 실행:

### GitHub Analyzer Agent
[PHASE:COLLECT:GITHUB]
- 경쟁사 오픈소스 프로젝트 분석
- 커밋 활동, 기여자, 기술 스택 파악

### Doc Searcher Agent
[PHASE:COLLECT:DOCS]
- Google Drive에서 기존 분석 자료 검색
- 관련 내부 문서 수집

### Web Researcher (WebSearch 도구)
[PHASE:COLLECT:WEB]
- 최신 뉴스 및 발표 검색
- 채용 공고 분석 (기술 스택 파악)

## Phase 2: 분석 종합

[PHASE:ANALYZE]
수집된 모든 정보를 종합하여:
- 기술 역량 평가
- 개발 속도 분석
- 인력 규모 추정

## Phase 3: 리포트 생성

[PHASE:REPORT]
Reporter Agent로 최종 리포트 생성 후:
- 마크다운 파일로 저장
- Slack 채널에 요약 공유
```

**utils.js** (공통 유틸리티 - [오케스트레이션 가이드](./claude_orchestration_guide.md#66-공통-유틸리티-utilsjs) 참조):
```javascript
// .claude/scripts/utils.js
// 기본 오케스트레이션 가이드의 utils.js와 동일
// 상세 코드는 claude_orchestration_guide.md 6.6절 참조
const fs = require('fs');
const path = require('path');
const STATE_FILE = path.join(__dirname, '..', 'state.json');

module.exports = {
  getState: () => fs.existsSync(STATE_FILE)
    ? JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'))
    : { phases: {}, results: {} },
  saveState: (state) => fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2)),
  getHookInput: () => JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}'),
  getHookOutput: () => process.env.CLAUDE_TOOL_OUTPUT || '',
  STATE_FILE
};
```

**pipeline-controller.js:**
```javascript
// .claude/scripts/pipeline-controller.js
const { getState, saveState, getHookInput, getHookOutput } = require('./utils');

const input = getHookInput();
const output = getHookOutput();
const state = getState();

// Phase 추출
const phaseMatch = input.prompt?.match(/\[PHASE:(\w+)(?::(\w+))?\]/);
if (!phaseMatch) {
  process.exit(0);  // 태그 없으면 통과
}

const phase = phaseMatch[1];
const subPhase = phaseMatch[2];

// 상태 업데이트
if (!state.phases) state.phases = {};
if (!state.results) state.results = {};

// Phase별 처리
switch (phase) {
  case 'COLLECT':
    // 수집 결과 저장
    state.results[subPhase] = output;
    state.phases[`COLLECT:${subPhase}`] = 'completed';

    // 모든 수집 완료 확인
    const collectPhases = ['GITHUB', 'DOCS', 'WEB'];
    const allCollected = collectPhases.every(p =>
      state.phases[`COLLECT:${p}`] === 'completed'
    );

    if (allCollected) {
      state.phases['COLLECT'] = 'completed';
      console.log('모든 정보 수집 완료. 분석 단계로 진행.');
    }
    break;

  case 'ANALYZE':
    state.results['ANALYSIS'] = output;
    state.phases['ANALYZE'] = 'completed';
    console.log('분석 완료. 리포트 생성 단계로 진행.');
    break;

  case 'REPORT':
    state.phases['REPORT'] = 'completed';
    console.log('리포트 생성 완료!');
    // 상태 초기화
    saveState({});
    process.exit(0);
}

saveState(state);
process.exit(0);
```

**Agent 정의 예시:**

**`.claude/agents/github-analyzer/github-analyzer.md`:**

    ---
    name: github-analyzer
    description: GitHub 저장소 분석 Agent
    tools: Read
    ---

    # GitHub Analyzer Agent

    경쟁사 GitHub 저장소를 분석합니다.

    ## MCP 도구 활용
    - `github_search_repositories`: 저장소 검색
    - `github_list_commits`: 최근 커밋 활동
    - `github_get_repository`: 저장소 상세 정보

    ## 출력 형식
    ```json
    {
      "agent": "github-analyzer",
      "repos": [...],
      "activity_score": 0-100,
      "tech_stack": ["언어", "프레임워크"],
      "contributors": 10
    }
    ```

**`.claude/agents/doc-searcher/doc-searcher.md`:**

    ---
    name: doc-searcher
    description: Google Drive 문서 검색 Agent
    tools: Read
    ---

    # Doc Searcher Agent

    내부 문서에서 관련 자료를 검색합니다.

    ## MCP 도구 활용
    - `gdrive_search`: 키워드로 문서 검색
    - `gdrive_read`: 문서 내용 읽기

    ## 출력 형식
    ```json
    {
      "agent": "doc-searcher",
      "documents": [
        {"title": "문서명", "summary": "요약", "url": "링크"}
      ]
    }
    ```

### 9.3 고급: 풀스택 배포 오케스트레이션

**목표**: 코드 변경 → 테스트 → 리뷰 → 배포 → 모니터링 전체 파이프라인

**프로젝트 구조:**
```
.claude/
├── settings.json
├── skills/
│   └── deploy-pipeline/
│       └── SKILL.md
├── agents/
│   ├── test-runner/
│   ├── security-scanner/
│   ├── deployer/
│   └── monitor/
└── scripts/
    ├── deploy-controller.js
    ├── rollback-handler.js
    └── utils.js
```

**settings.json:**
```jsonc
{
  "hooks": {
    "preToolUse": [{
      "matcher": "aws_*",
      "command": "node .claude/scripts/deploy-pre-check.js"
    }],
    "postToolUse": [{
      "matcher": "Task",
      "command": "node .claude/scripts/deploy-controller.js"
    }]
  },
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    },
    "aws": {
      "command": "npx",
      "args": ["-y", "@aws/mcp-server-aws"],
      "env": {
        "AWS_ACCESS_KEY_ID": "${AWS_ACCESS_KEY_ID}",
        "AWS_SECRET_ACCESS_KEY": "${AWS_SECRET_ACCESS_KEY}",
        "AWS_REGION": "${AWS_REGION}"
      }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "playwright-mcp"]
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-slack"],
      "env": { "SLACK_TOKEN": "${SLACK_TOKEN}" }
    }
  }
}
```

**SKILL.md:**
```yaml
---
name: deploy-pipeline
description: 풀스택 배포 파이프라인
allowed-tools: Task, Read, Write, Bash
---

# 배포 파이프라인

## 체크포인트 시스템
각 단계 완료 시 자동 저장됨. 실패 시 롤백 가능.

## Phase 1: 코드 검증
[PHASE:VALIDATE checkpoint:pre-test]

### Test Runner Agent
- 단위 테스트 실행
- 통합 테스트 실행
- 커버리지 확인

**통과 조건**: 테스트 100% 통과, 커버리지 80% 이상

## Phase 2: 보안 검사
[PHASE:SECURITY checkpoint:pre-security]

### Security Scanner Agent
- 의존성 취약점 검사
- 코드 정적 분석
- 비밀 키 노출 확인

**통과 조건**: Critical/High 취약점 없음

## Phase 3: 스테이징 배포
[PHASE:STAGING checkpoint:pre-staging]

### Deployer Agent
AWS MCP 사용:
- `aws_ecs_update_service`: 컨테이너 업데이트
- `aws_cloudfront_invalidation`: CDN 캐시 무효화

### E2E 테스트
Playwright MCP로 스테이징 환경 테스트

## Phase 4: 프로덕션 배포
[PHASE:PRODUCTION checkpoint:pre-prod]

### 승인 대기
⚠️ **인간 승인 필요**

### 블루-그린 배포
1. 새 버전 배포
2. 헬스체크
3. 트래픽 전환

## Phase 5: 모니터링
[PHASE:MONITOR]

### Monitor Agent
배포 후 30분간:
- 에러율 모니터링
- 응답시간 확인
- 리소스 사용량 체크

**롤백 조건**: 에러율 1% 초과 또는 응답시간 2배 증가

## 알림
각 단계 결과를 Slack으로 알림
실패 시 즉시 담당자 멘션
```

**deploy-controller.js** (체크포인트/롤백 기능 포함):
```javascript
// .claude/scripts/deploy-controller.js
// 주의: saveCheckpoint, rollback은 오케스트레이션 가이드의 utils.js에서 가져옴
const fs = require('fs');
const path = require('path');
const STATE_FILE = path.join(__dirname, '..', 'state.json');

// 유틸리티 함수들
function getState() {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  }
  return { phases: {}, results: {}, checkpoints: {} };
}

function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function getHookInput() {
  return JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
}

function getHookOutput() {
  return process.env.CLAUDE_TOOL_OUTPUT || '';
}

function saveCheckpoint(name) {
  const state = getState();
  state.checkpoints = state.checkpoints || {};
  state.checkpoints[name] = {
    timestamp: Date.now(),
    phases: { ...state.phases },
    results: { ...state.results }
  };
  saveState(state);
  console.log(`[Checkpoint] ${name} 저장됨`);
}

function rollback(checkpointName) {
  const state = getState();
  const cp = state.checkpoints?.[checkpointName];
  if (cp) {
    state.phases = { ...cp.phases };
    state.results = { ...cp.results };
    saveState(state);
    console.log(`[Rollback] ${checkpointName}으로 복구됨`);
    return true;
  }
  console.error(`[Rollback] ${checkpointName} 체크포인트 없음`);
  return false;
}

// 메인 로직
const input = getHookInput();
const output = getHookOutput();
const state = getState();

// Phase 및 체크포인트 추출
const phaseMatch = input.prompt?.match(/\[PHASE:(\w+)(?:\s+checkpoint:(\w+))?\]/);
if (!phaseMatch) {
  process.exit(0);
}

const phase = phaseMatch[1];
const checkpointName = phaseMatch[2];

// 결과 파싱
let result;
try {
  result = JSON.parse(output);
} catch (e) {
  result = { status: 'unknown', output: output };
}

// 체크포인트 저장
if (checkpointName) {
  saveCheckpoint(checkpointName);
}

// Phase별 검증
switch (phase) {
  case 'VALIDATE':
    if (result.status === 'failed' || result.coverage < 80) {
      console.error('테스트 실패 또는 커버리지 부족');
      process.exit(1);
    }
    break;

  case 'SECURITY':
    if (result.critical > 0 || result.high > 0) {
      console.error(`보안 취약점 발견: Critical ${result.critical}, High ${result.high}`);
      process.exit(1);
    }
    break;

  case 'STAGING':
    if (result.status !== 'healthy') {
      console.error('스테이징 배포 실패. pre-staging으로 롤백.');
      rollback('pre-staging');
      process.exit(1);
    }
    break;

  case 'PRODUCTION':
    if (result.status !== 'healthy') {
      console.error('프로덕션 배포 실패. pre-prod로 롤백.');
      rollback('pre-prod');
      // 롤백 실행 알림
      state.needsRollback = true;
      saveState(state);
      process.exit(1);
    }
    break;

  case 'MONITOR':
    if (result.errorRate > 0.01 || result.latencyIncrease > 2) {
      console.error('모니터링 이상 감지. 자동 롤백.');
      rollback('pre-prod');
      state.needsRollback = true;
      state.rollbackReason = `에러율: ${result.errorRate}, 지연 증가: ${result.latencyIncrease}x`;
      saveState(state);
      process.exit(1);
    }
    console.log('배포 성공! 모니터링 정상.');
    // 상태 초기화
    saveState({});
    break;
}

// 상태 업데이트
state.currentPhase = phase;
state.phases = state.phases || {};
state.phases[phase] = 'completed';
saveState(state);

process.exit(0);
```

---

## 연관 문서

- [Claude Code 멀티 에이전트 오케스트레이션 가이드](./claude_orchestration_guide.md) - Skill, Agent, Hook 기본 개념
- [MCP 공식 스펙](https://modelcontextprotocol.io/specification/2025-11-25) - 2025년 11월 스펙
- [MCP 1주년 블로그](https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/) - 2025년 주요 발전사항

---

## 요약

| 구성 요소 | 역할 |
|----------|------|
| **MCP Server** | 외부 시스템과의 표준화된 연결 |
| **Skill + MCP** | 여러 MCP 서버를 조합한 오케스트레이션 |
| **Agent + MCP** | 전문화된 역할에 특정 MCP 도구 할당 |
| **Hook + MCP** | MCP 호출 전/후 검증 및 제어 |

**핵심 공식:**
```
안전한 MCP 통합 = Skill (오케스트레이션)
                + Agent (전문화)
                + Hook (검증)
                + 최소 권한 원칙
```

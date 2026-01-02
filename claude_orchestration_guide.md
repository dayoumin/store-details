# Claude Code 멀티 에이전트 오케스트레이션 가이드

Claude Code CLI에서 Skill, Agent, Hook을 조합하여 신뢰할 수 있는 멀티 에이전트 워크플로우를 구축하는 방법을 다룹니다.

---

## 목차

1. [개요](#1-개요)
   - 1.1 Skill vs Agent 기본 개념
   - 1.2 언제 무엇을 쓰는가
2. [핵심 아키텍처](#2-핵심-아키텍처)
   - 2.1 Claude Code 시스템 구조
   - 2.2 세션 독립성
3. [조합 패턴](#3-조합-패턴)
   - 3.1 Agent 안에 Skill
   - 3.2 Skill 안에 Agent
   - 3.3 왜 Skill이 오케스트레이터로 강력한가
4. [Hook 시스템](#4-hook-시스템)
   - 4.1 Hook 정의 위치
   - 4.2 Hook 발동 조건
   - 4.3 Hook 환경변수
   - 4.4 Hook 종료 코드
   - 4.5 시스템 레벨 발동 원리
   - 4.6 스크립트에서 컨텍스트 필터링
   - 4.7 상태 관리
5. [고급 워크플로우 패턴](#5-고급-워크플로우-패턴)
   - 5.1 분기 / 5.2 검증 / 5.3 반복 제한
   - 5.4 결과 종합 / 5.5 회고 / 5.6 다중 분기
   - 5.7 워크트리/DAG / 5.8 투표/합의 / 5.9 경쟁
   - 5.10 체크포인트/롤백 / 5.11 에러 핸들링
6. [실전 예시](#6-실전-예시)
   - 6.1 기본: 단일 검증
   - 6.2 중급: 회고 루프
   - 6.3 고급: 풀 파이프라인
   - 6.4 프로젝트 구조
   - 6.5 Agent 정의 파일 예시
   - 6.6 공통 유틸리티 (utils.js)
   - 6.7 Skill에서 사용 가능한 도구 목록
7. [한계점 및 확장](#7-한계점-및-확장)
   - 7.1 Claude Code CLI 한계
   - 7.2 Agent SDK로 전환 시점
   - 7.3 MCP로 확장

---

## 1. 개요

### 1.1 Skill vs Agent 기본 개념

| | **Skill** | **Agent** |
|---|-----------|-----------|
| **정의** | 재사용 가능한 프롬프트 템플릿 | 독립된 컨텍스트의 작업자 |
| **위치** | `.claude/skills/` | `.claude/agents/` |
| **특징** | 명령어로 호출 (`/skill-name`) | Task 도구로 호출 |
| **컨텍스트** | 메인 모델과 공유 | 독립/격리됨 |

### 1.2 언제 무엇을 쓰는가

| 상황 | 선택 |
|------|------|
| "이거 자주 쓰니까 명령어로 만들자" | **Skill** |
| "알아서 탐색하고 판단해야 해" | **Agent** |
| "명령어인데 내부가 복잡해" | **Skill → Agent** |
| "작업 중에 정형화된 단계 필요" | **Agent → Skill** |

**핵심 차이점:**
- Agent는 하위에 다른 Agent를 둘 수 없음
- Skill 안에서는 여러 Agent를 병렬로 호출 가능
- 이 차이가 Skill을 오케스트레이터로 만드는 핵심

---

## 2. 핵심 아키텍처

### 2.1 Claude Code 시스템 구조

```
┌─────────────────────────────────────────────┐
│  Claude Code 시스템 (Harness/Runtime)        │
│                                             │
│  - 도구 실행 관리                            │
│  - Hook 발동                                │
│  - 세션 관리                                │
│                                             │
│  ┌─────────────┐      ┌─────────────┐      │
│  │ 메인 모델    │      │ Agent 모델   │      │
│  │ (LLM)       │      │ (LLM)       │      │
│  └─────────────┘      └─────────────┘      │
│                                             │
└─────────────────────────────────────────────┘
```

**중요**: 모델(LLM)과 시스템(Runtime)은 분리되어 있음
- **모델**: 생각하고 도구 호출 요청
- **시스템**: 실제 도구 실행, Hook 발동, 세션 관리

### 2.2 세션 독립성

```
메인 모델 (세션 A)
    │
    ├── settings.json 읽기 ✅
    ├── Hook 적용 ✅ (시스템이 발동)
    │
    └── Task 도구로 Agent 호출
            │
            ▼
        Agent (세션 B) - 독립/격리
            │
            ├── settings.json 직접 읽기 ❌
            ├── Hook 인식 ❌ (하지만 시스템이 발동함)
            └── 결과만 반환
```

**중요 구분:**
- **모델 관점**: Agent는 Hook의 존재를 모름
- **시스템 관점**: Agent가 도구 호출해도 Hook은 발동됨

Agent는 **격리된 컨텍스트**에서 실행되지만, 시스템 레벨의 Hook은 여전히 적용됨.

---

## 3. 조합 패턴

### 3.1 Agent 안에 Skill

```
Agent (복잡한 작업 수행)
  └── Skill 호출 (특정 단계에서)
```

**사용 케이스:**
- Agent가 코드 리뷰 중 `/commit` 스킬 호출
- Agent가 문서 작성 중 `/pdf` 스킬로 변환
- 큰 작업 흐름 안에서 정형화된 단계 실행

### 3.2 Skill 안에 Agent (핵심 패턴)

```
Skill (오케스트레이터)
  ├── Agent A (코드 분석) ──┐
  ├── Agent B (테스트 검토) ──┼── 병렬 실행
  ├── Agent C (문서 검토) ──┘
  └── 결과 종합 후 출력
```

**사용 케이스:**
- `/full-review` 스킬로 여러 관점 동시 분석
- `/deploy` 스킬로 빌드, 테스트, 배포 파이프라인
- 복잡한 워크플로우를 단일 명령어로 실행

### 3.3 왜 Skill이 오케스트레이터로 강력한가

| | Agent | Skill |
|---|-------|-------|
| 하위 Agent | ❌ 불가 | ✅ 여러 개 가능 |
| 병렬 실행 | 단일 흐름 | 동시 실행 가능 |
| 역할 | 단일 전문가 | **팀 리더** |

Skill은 **버튼**, Agent는 **조수**라고 생각하면 됨.

---

## 4. Hook 시스템

### 4.1 Hook 정의 위치

```jsonc
// .claude/settings.json
{
  "hooks": {
    "preToolUse": [
      {
        "matcher": "Task",
        "command": "node .claude/scripts/pre-check.js"
      }
    ],
    "postToolUse": [
      {
        "matcher": "Task",
        "command": "node .claude/scripts/post-validate.js"
      }
    ]
  }
}
```

Hook은 **오직 settings.json에서만** 정의됨.

### 4.2 Hook 발동 조건

**matcher 조건만 맞으면 무조건 발동 (시스템 레벨):**

| 호출 주체 | Hook 발동 | 설명 |
|----------|----------|------|
| 사용자 직접 | ✅ | 사용자가 직접 도구 요청 |
| 메인 모델 | ✅ | 메인 모델이 도구 호출 |
| Skill 내에서 | ✅ | Skill 실행 중 도구 호출 |
| Agent 내에서 | ✅ | Agent가 도구 호출해도 **시스템이** 발동 |

Hook은 **"누가"가 아니라 "무엇을"** 기준으로 발동.

**주의**: Agent는 Hook의 존재를 모르지만, Agent가 도구를 호출하면 시스템이 Hook을 발동함.

### 4.3 Hook 환경변수

Hook 스크립트에서 사용 가능한 환경변수:

| 환경변수 | 설명 | 사용 시점 |
|---------|------|----------|
| `CLAUDE_TOOL_INPUT` | 도구 호출 입력 (JSON) | pre/post |
| `CLAUDE_TOOL_OUTPUT` | 도구 실행 결과 | postToolUse만 |
| `CLAUDE_TOOL_NAME` | 호출된 도구 이름 | pre/post |

```javascript
// 환경변수 사용 예시
const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const output = process.env.CLAUDE_TOOL_OUTPUT || '';
const toolName = process.env.CLAUDE_TOOL_NAME || '';
```

### 4.4 Hook 종료 코드

| 종료 코드 | 의미 | 결과 |
|----------|------|------|
| `process.exit(0)` | 성공/통과 | 작업 계속 진행 |
| `process.exit(1)` | 실패/차단 | 작업 중단, 에러 반환 |

```javascript
// 검증 통과
if (isValid) {
  process.exit(0);  // 계속 진행
}

// 검증 실패
console.error("검증 실패 이유");
process.exit(1);  // 작업 중단
```

### 4.5 시스템 레벨 발동 원리

```
1. 메인 모델: "Task 도구 호출할게"
       │
       ▼
2. 시스템: preToolUse Hook 실행 ✅
       │
       ▼
3. 시스템: Agent 세션 생성 & 실행
       │
       ▼
4. Agent 모델: (독립적으로 작업, Hook 모름)
       │
       ▼
5. 시스템: Agent 결과 수신
       │
       ▼
6. 시스템: postToolUse Hook 실행 ✅
       │
       ▼
7. 메인 모델: 결과 받음
```

**핵심**: Hook은 모델이 아닌 **시스템(Runtime)이 발동**. 모델이 우회 불가능.

### 4.6 스크립트에서 컨텍스트 필터링

모든 도구 호출에 Hook이 발동되므로, 스크립트에서 필터링 필요:

```javascript
// .claude/scripts/post-validate.js
const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const output = process.env.CLAUDE_TOOL_OUTPUT || '';

// 특정 워크플로우만 제어
if (input.prompt?.includes('[AUDIT]')) {
  // 검증 로직
  if (output.includes('ERROR') || !output.includes('완료')) {
    console.error("검증 실패");
    process.exit(1);
  }
  console.log("검증 통과");
  process.exit(0);
} else {
  // 나머지는 그냥 통과
  process.exit(0);
}
```

### 4.7 상태 관리 (.claude/state.json)

Hook 간 상태 공유를 위한 파일 기반 상태 관리:

```javascript
// .claude/scripts/post-validate.js
const fs = require('fs');
const STATE_FILE = '.claude/state.json';

// 상태 읽기
function getState() {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE));
  }
  return { retryCount: 0, checkpoints: [] };
}

// 상태 저장
function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// 사용 예시
const state = getState();
if (state.retryCount >= 3) {
  console.log("최대 반복 횟수 도달");
  process.exit(1);
}
state.retryCount++;
saveState(state);
```

---

## 5. 고급 워크플로우 패턴

### 5.1 분기 (Branching)

조건에 따라 다른 Agent 호출:

```
입력 분석
    │
    ├── 타입 A → Agent A
    ├── 타입 B → Agent B
    └── 타입 C → Agent C
```

**Skill 구현:**
```yaml
---
name: smart-router
---
# 스마트 라우터

입력을 분석하여:
- 프론트엔드 관련 → frontend-agent 호출
- 백엔드 관련 → backend-agent 호출
- DB 관련 → database-agent 호출
```

### 5.2 검증 (Validation)

Agent 결과를 다른 Agent가 검증:

```
Agent A (작업)
    │
    ▼
Agent B (검증)
    │
    ├── 통과 → 완료
    └── 실패 → Agent A 재작업
```

**Hook 스크립트:**
```javascript
// postToolUse Hook에서 결과 검증
const output = process.env.CLAUDE_TOOL_OUTPUT || '';

if (!output.includes('PASS')) {
  console.log("검증 실패, 재작업 필요");
  process.exit(1);  // 작업 중단
}
process.exit(0);  // 통과
```

### 5.3 반복 제한 (Loop Control)

무한 루프 방지:

```javascript
// .claude/scripts/loop-control.js
const { getState, saveState, resetState } = require('./utils');

const state = getState();

if (state.retryCount >= 3) {
  console.error("최대 반복 횟수(3회) 초과");
  resetState();
  process.exit(1);
}

state.retryCount++;
saveState(state);
process.exit(0);
```

### 5.4 결과 종합 (Aggregation)

여러 Agent 결과를 하나로:

```
Agent A 결과 ─┐
Agent B 결과 ─┼→ 종합 로직 → 최종 리포트
Agent C 결과 ─┘
```

**Skill에서 구조화된 출력 요청:**
```yaml
각 Agent는 결과를 JSON 형식으로 반환:
{
  "agent": "이름",
  "status": "pass/fail",
  "findings": [...],
  "score": 0-100
}

모든 결과를 종합하여 최종 리포트 생성.
```

### 5.5 회고 (Reflection)

자기 수정 패턴:

```
Agent A: 초안 작성
    │
    ▼
Agent B (리뷰어): "이 부분 문제 있어"
    │
    ▼
Agent A: 피드백 반영하여 수정
    │
    ▼
Agent C: 최종 검증
```

**Skill 구현:**
```yaml
---
name: reflective-coder
---
# 회고형 코드 작성

1. coder-agent: 코드 작성
2. reviewer-agent: 코드 리뷰 (문제점 지적)
3. coder-agent: 리뷰 반영하여 수정
4. verifier-agent: 최종 검증

리뷰어 피드백은 반드시 수정에 반영할 것.
```

### 5.6 다중 분기 (Multi-Branch)

동시에 여러 경로로 분기:

```
         ┌→ Agent A (프론트엔드) ─┐
         │                       │
입력 → 분류 → Agent B (백엔드) ───┼→ 결과 종합
         │                       │
         └→ Agent C (인프라) ────┘
```

**Skill에서 병렬 실행 지시:**
```yaml
다음 3개 Agent를 동시에 실행:
1. Task로 frontend-agent 호출
2. Task로 backend-agent 호출
3. Task로 infra-agent 호출

모든 결과가 돌아오면 종합.
```

### 5.7 워크트리/DAG

의존성이 있는 복잡한 파이프라인:

```
        A (분석)
       / \
      B   C (A 완료 후 병렬)
      |   |
      D   E (각각 B, C 완료 후)
       \ /
        F (D, E 완료 후 종합)
```

**상태 파일로 의존성 관리:**
```javascript
// .claude/scripts/dag-controller.js
const { getState } = require('./utils');

const state = getState();

const dependencies = {
  'B': ['A'],
  'C': ['A'],
  'D': ['B'],
  'E': ['C'],
  'F': ['D', 'E']
};

function canRun(task) {
  const deps = dependencies[task] || [];
  return deps.every(d => state.completed.includes(d));
}
```

### 5.8 투표/합의 (Consensus)

여러 Agent의 의견을 종합:

```
Agent A → 답변 1 ─┐
Agent B → 답변 2 ─┼→ 다수결 → 최종 결정
Agent C → 답변 3 ─┘
```

**활용:**
- 중요 결정에서 신뢰도 향상
- 단일 Agent 편향 방지

**Skill 구현:**
```yaml
3개 Agent에게 동일 질문:
- analyst-1, analyst-2, analyst-3

각 답변을 비교하여:
- 2개 이상 일치 → 채택
- 모두 다름 → 추가 논의 또는 인간 개입
```

### 5.9 경쟁 (Racing)

여러 접근법 중 최선 선택:

```
Agent A (접근법 1) ─┐
Agent B (접근법 2) ─┼→ 가장 좋은 결과 채택
Agent C (접근법 3) ─┘
```

**선택 기준:**
- 먼저 완료된 결과 (속도)
- 가장 높은 점수 (품질)
- 특정 조건 충족 (요구사항)

### 5.10 체크포인트/롤백

긴 워크플로우에서 안전망:

```
작업 1 → [체크포인트 1] → 작업 2 → [체크포인트 2] → 작업 3
                                        │
                                   실패시 롤백
                                        │
                                        ▼
                               [체크포인트 1]로 복구
```

**스크립트 구현:**
```javascript
// 체크포인트 저장
function saveCheckpoint(name, data) {
  const state = getState();
  state.checkpoints[name] = {
    timestamp: Date.now(),
    data: data
  };
  saveState(state);
}

// 롤백
function rollback(checkpointName) {
  const state = getState();
  const checkpoint = state.checkpoints[checkpointName];
  if (checkpoint) {
    // 상태 복구 로직
    return checkpoint.data;
  }
  throw new Error(`Checkpoint ${checkpointName} not found`);
}
```

### 5.11 에러 핸들링/폴백

실패 시 대체 경로:

```
Agent A (주 작업)
    │
    ├── 성공 → 완료
    │
    └── 실패 → Agent B (폴백)
                  │
                  ├── 성공 → 완료
                  │
                  └── 실패 → 인간 개입 요청
```

**Hook 스크립트:**
```javascript
// .claude/scripts/fallback-handler.js
const { getState, saveState, getHookOutput } = require('./utils');

const output = getHookOutput();
const state = getState();

// 결과를 JSON으로 파싱 시도
let result = { status: 'unknown' };
try {
  result = JSON.parse(output);
} catch (e) {
  result.status = 'failed';
}

if (result.status === 'failed') {
  if (!state.usedFallback) {
    state.usedFallback = true;
    state.nextAgent = 'fallback-agent';
    saveState(state);
    console.log("폴백 Agent로 전환");
    process.exit(0); // 계속 진행
  } else {
    console.error("폴백도 실패. 인간 개입 필요.");
    process.exit(1); // 중단
  }
}
```

---

## 6. 실전 예시

### 6.1 기본: 단일 검증 (Skill + Hook)

**목표**: Task 호출 결과를 검증하고 실패시 재시도

**프로젝트 구조:**
```
.claude/
├── settings.json
├── state.json
├── skills/
│   └── verified-task/
│       └── SKILL.md
└── scripts/
    └── verify-result.js
```

**settings.json:**
```jsonc
{
  "hooks": {
    "postToolUse": [{
      "matcher": "Task",
      "command": "node .claude/scripts/verify-result.js"
    }]
  }
}
```

**SKILL.md:**
```yaml
---
name: verified-task
description: 검증이 포함된 작업 실행
---
# 검증된 작업

프롬프트에 [VERIFY] 태그를 포함하여 Task 호출.
결과는 자동으로 검증됨.
```

**verify-result.js:**
```javascript
const fs = require('fs');
const STATE_FILE = '.claude/state.json';

const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const output = process.env.CLAUDE_TOOL_OUTPUT || '';

// [VERIFY] 태그가 있는 경우만 검증
if (!input.prompt?.includes('[VERIFY]')) {
  process.exit(0);
}

// 상태 관리
let state = { retryCount: 0 };
if (fs.existsSync(STATE_FILE)) {
  state = JSON.parse(fs.readFileSync(STATE_FILE));
}

// 최대 3회 재시도
if (state.retryCount >= 3) {
  console.error("최대 재시도 횟수 초과");
  fs.unlinkSync(STATE_FILE);
  process.exit(1);
}

// 실제 검증 로직
const isValid = validateOutput(output);
if (!isValid) {
  state.retryCount++;
  fs.writeFileSync(STATE_FILE, JSON.stringify(state));
  console.error(`검증 실패. 재시도 ${state.retryCount}/3`);
  process.exit(1);  // 실패 → 재시도 유도
}

// 성공시 상태 초기화
fs.unlinkSync(STATE_FILE);
console.log("검증 통과!");
process.exit(0);

// 검증 함수 (프로젝트에 맞게 수정)
function validateOutput(output) {
  // 예시: 결과에 에러가 없고, 필수 키워드가 포함되어야 함
  if (output.includes('ERROR') || output.includes('error')) {
    return false;
  }
  if (!output.includes('완료') && !output.includes('PASS')) {
    return false;
  }
  return true;
}
```

---

### 6.2 중급: 회고 루프 (Reflection Loop)

**목표**: 코드 작성 → 리뷰 → 수정 → 최종 검증

**프로젝트 구조:**
```
.claude/
├── settings.json
├── state.json
├── skills/
│   └── reflective-coder/
│       └── SKILL.md
├── agents/
│   ├── coder/
│   │   └── coder.md
│   ├── reviewer/
│   │   └── reviewer.md
│   └── verifier/
│       └── verifier.md
└── scripts/
    ├── reflection-control.js
    └── utils.js
```

**settings.json:**
```jsonc
{
  "hooks": {
    "postToolUse": [{
      "matcher": "Task",
      "command": "node .claude/scripts/reflection-control.js"
    }]
  }
}
```

**SKILL.md:**
```yaml
---
name: reflective-coder
description: 회고를 통해 품질을 높이는 코드 작성
allowed-tools: Task, Read, Write
---
# 회고형 코드 작성

## 실행 순서

### 1단계: 초안 작성
[REFLECT:DRAFT] 태그와 함께 coder agent 호출

### 2단계: 리뷰
[REFLECT:REVIEW] 태그와 함께 reviewer agent 호출
- 문제점과 개선사항을 구체적으로 지적

### 3단계: 수정
[REFLECT:REVISE] 태그와 함께 coder agent 재호출
- 리뷰 피드백을 반드시 반영

### 4단계: 최종 검증
[REFLECT:VERIFY] 태그와 함께 verifier agent 호출
- 통과시 완료
- 실패시 2단계로 돌아감 (최대 2회)

## 주의사항
- 각 단계의 태그를 정확히 사용할 것
- 리뷰 피드백은 다음 단계에 전달할 것
```

**reflection-control.js:**
```javascript
// .claude/scripts/reflection-control.js
const fs = require('fs');
const STATE_FILE = '.claude/state.json';

function getState() {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE));
  }
  return {
    phase: 'draft',
    reflectionCount: 0,
    maxReflections: 2
  };
}

function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const prompt = input.prompt || '';

// 회고 워크플로우가 아니면 통과
if (!prompt.includes('[REFLECT:')) {
  process.exit(0);
}

const state = getState();

if (prompt.includes('[REFLECT:VERIFY]')) {
  // 검증 단계
  const output = process.env.CLAUDE_TOOL_OUTPUT || '';

  if (output.includes('PASS')) {
    console.log("최종 검증 통과!");
    fs.unlinkSync(STATE_FILE);
    process.exit(0);
  } else {
    state.reflectionCount++;
    if (state.reflectionCount >= state.maxReflections) {
      console.error("최대 회고 횟수 도달. 인간 검토 필요.");
      process.exit(1);
    }
    state.phase = 'review';
    saveState(state);
    console.log(`검증 실패. 회고 ${state.reflectionCount}/${state.maxReflections}`);
    process.exit(0);
  }
}

process.exit(0);
```

---

### 6.3 고급: 풀 파이프라인

**목표**: 다중 분기 + 병렬 실행 + 투표 + 체크포인트 + 에러 핸들링

**프로젝트 구조:**
```
.claude/
├── settings.json
├── state.json
├── skills/
│   └── full-audit/
│       └── SKILL.md
├── agents/
│   ├── code-analyzer/
│   ├── security-reviewer/
│   ├── performance-checker/
│   ├── fallback-analyzer/
│   └── consensus-resolver/
└── scripts/
    ├── pipeline-controller.js
    ├── checkpoint-manager.js
    ├── voting-system.js
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
  }
}
```

**SKILL.md:**
```yaml
---
name: full-audit
description: 완전한 코드 감사 파이프라인
allowed-tools: Task, Read, Write, Bash
---
# 종합 코드 감사

## 파이프라인 개요

```
[시작]
   │
   ▼
[체크포인트 0: 초기 상태]
   │
   ▼
┌──┴──┬─────────┐
│     │         │
▼     ▼         ▼
코드   보안      성능     ← 병렬 실행
분석   검토      체크
│     │         │
└──┬──┴─────────┘
   │
   ▼
[체크포인트 1: 분석 완료]
   │
   ▼
[투표/합의]
   │
   ├── 합의 도달 → 최종 리포트
   │
   └── 합의 실패 → consensus-resolver
                      │
                      └── 실패시 → 인간 개입
```

## 실행 지시

### Phase 1: 병렬 분석
[AUDIT:ANALYZE] 태그와 함께 3개 Agent 동시 호출:
- code-analyzer: [AUDIT:CODE]
- security-reviewer: [AUDIT:SECURITY]
- performance-checker: [AUDIT:PERF]

### Phase 2: 결과 수집
각 Agent 결과를 JSON 형식으로 수집

### Phase 3: 투표
[AUDIT:VOTE] 3개 결과의 심각도 판정 비교
- 2개 이상 일치 → 채택
- 모두 다름 → consensus-resolver 호출

### Phase 4: 리포트
[AUDIT:REPORT] 최종 종합 리포트 생성

## 에러 처리
- Agent 실패시 fallback-analyzer로 대체
- fallback도 실패시 해당 영역 스킵하고 경고 표시
- 2개 이상 영역 실패시 중단 및 인간 개입 요청

## 체크포인트
각 Phase 완료시 자동 저장됨
실패시 이전 체크포인트로 롤백 가능
```

**pipeline-controller.js:**
```javascript
// .claude/scripts/pipeline-controller.js
const fs = require('fs');
const STATE_FILE = '.claude/state.json';

// 상태 관리
function getState() {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE));
  }
  return {
    phase: 'init',
    results: {},
    checkpoints: {},
    failedAgents: [],
    usedFallback: {}
  };
}

function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function saveCheckpoint(name, state) {
  state.checkpoints[name] = {
    timestamp: Date.now(),
    phase: state.phase,
    results: { ...state.results }
  };
  saveState(state);
  console.log(`체크포인트 저장: ${name}`);
}

function rollback(state, checkpointName) {
  const cp = state.checkpoints[checkpointName];
  if (cp) {
    state.phase = cp.phase;
    state.results = { ...cp.results };
    saveState(state);
    console.log(`롤백 완료: ${checkpointName}`);
    return true;
  }
  return false;
}

// 메인 로직
const input = JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
const output = process.env.CLAUDE_TOOL_OUTPUT || '';
const prompt = input.prompt || '';

// AUDIT 워크플로우가 아니면 통과
if (!prompt.includes('[AUDIT:')) {
  process.exit(0);
}

const state = getState();

// Phase별 처리
if (prompt.includes('[AUDIT:ANALYZE]')) {
  saveCheckpoint('pre-analyze', state);
  state.phase = 'analyzing';
  saveState(state);
}

if (prompt.includes('[AUDIT:CODE]') ||
    prompt.includes('[AUDIT:SECURITY]') ||
    prompt.includes('[AUDIT:PERF]')) {

  // 결과 파싱 시도
  try {
    const result = JSON.parse(output);
    const agentType = prompt.match(/\[AUDIT:(\w+)\]/)[1].toLowerCase();
    state.results[agentType] = result;
    saveState(state);
  } catch (e) {
    // 실패 처리
    const agentType = prompt.match(/\[AUDIT:(\w+)\]/)[1].toLowerCase();

    if (!state.usedFallback[agentType]) {
      state.usedFallback[agentType] = true;
      state.failedAgents.push(agentType);
      saveState(state);
      console.log(`${agentType} 실패. 폴백으로 전환.`);
    } else {
      state.failedAgents.push(agentType + '-fallback');
      saveState(state);
      console.error(`${agentType} 폴백도 실패.`);

      // 2개 이상 실패시 중단
      if (state.failedAgents.length >= 2) {
        console.error("다수 영역 실패. 인간 개입 필요.");
        process.exit(1);
      }
    }
  }
}

if (prompt.includes('[AUDIT:VOTE]')) {
  saveCheckpoint('pre-vote', state);

  // 투표 로직은 voting-system.js에서 처리
  const results = Object.values(state.results);
  if (results.length < 2) {
    console.error("투표에 필요한 결과 부족");
    rollback(state, 'pre-analyze');
    process.exit(1);
  }
}

if (prompt.includes('[AUDIT:REPORT]')) {
  // 최종 리포트 생성 완료
  console.log("감사 완료!");
  fs.unlinkSync(STATE_FILE);
}

process.exit(0);
```

**voting-system.js:**
```javascript
// .claude/scripts/voting-system.js
// 투표/합의 시스템
function calculateConsensus(results) {
  const severities = results.map(r => r.severity || 'unknown');

  // 다수결
  const counts = {};
  severities.forEach(s => {
    counts[s] = (counts[s] || 0) + 1;
  });

  const maxCount = Math.max(...Object.values(counts));
  const winner = Object.keys(counts).find(k => counts[k] === maxCount);

  return {
    consensus: maxCount >= 2,
    result: winner,
    votes: counts
  };
}

module.exports = { calculateConsensus };
```

---

### 6.4 프로젝트 구조 예시

완전한 프로젝트 구조:

```
my-project/
├── .claude/
│   ├── settings.json          # Hook 정의
│   ├── state.json             # 런타임 상태 (gitignore)
│   │
│   ├── skills/
│   │   ├── verified-task/
│   │   │   └── SKILL.md
│   │   ├── reflective-coder/
│   │   │   └── SKILL.md
│   │   └── full-audit/
│   │       └── SKILL.md
│   │
│   ├── agents/
│   │   ├── code-analyzer/
│   │   │   └── code-analyzer.md
│   │   ├── security-reviewer/
│   │   │   └── security-reviewer.md
│   │   ├── performance-checker/
│   │   │   └── performance-checker.md
│   │   ├── reviewer/
│   │   │   └── reviewer.md
│   │   ├── verifier/
│   │   │   └── verifier.md
│   │   └── fallback-analyzer/
│   │       └── fallback-analyzer.md
│   │
│   └── scripts/
│       ├── utils.js           # 공통 유틸리티
│       ├── verify-result.js   # 기본 검증
│       ├── reflection-control.js  # 회고 제어
│       ├── pipeline-controller.js # 파이프라인 제어
│       ├── checkpoint-manager.js  # 체크포인트 관리
│       └── voting-system.js   # 투표 시스템
│
├── src/                       # 프로젝트 소스 코드
├── tests/
└── package.json
```

**.gitignore에 추가:**
```
.claude/state.json
```

---

### 6.5 Agent 정의 파일 예시

**`.claude/agents/code-analyzer/code-analyzer.md`:**
```markdown
---
name: code-analyzer
description: 코드 구조와 품질을 분석하는 전문 Agent
tools: Read, Grep, Glob
---

# Code Analyzer Agent

당신은 코드베이스 분석 전문가입니다.

## 분석 항목

1. **구조 분석**: 디렉토리 구조, 모듈 구성
2. **복잡도 분석**: 함수별 복잡도, 의존성
3. **품질 지표**: 코드 중복, 네이밍 컨벤션

## 출력 형식

반드시 다음 JSON 형식으로 결과 반환:

```json
{
  "agent": "code-analyzer",
  "status": "pass|fail",
  "severity": "low|medium|high|critical",
  "findings": [
    {
      "type": "complexity",
      "file": "파일경로",
      "message": "설명"
    }
  ],
  "score": 0-100
}
```

## 주의사항

- 추측하지 말고 실제 코드만 분석
- 발견된 문제는 구체적인 파일과 라인 명시
- 심각도를 객관적으로 판단
```

**`.claude/agents/reviewer/reviewer.md`:**
```markdown
---
name: reviewer
description: 코드 리뷰를 수행하는 Agent
tools: Read, Grep
---

# Code Reviewer Agent

당신은 시니어 개발자로서 코드를 리뷰합니다.

## 리뷰 기준

1. **가독성**: 코드가 이해하기 쉬운가?
2. **유지보수성**: 수정이 용이한가?
3. **버그 가능성**: 잠재적 버그가 있는가?
4. **베스트 프랙티스**: 모범 사례를 따르는가?

## 피드백 형식

```
## 문제점
- [심각도] 파일:라인 - 문제 설명

## 개선 제안
- 구체적인 수정 방법

## 총평
PASS 또는 FAIL (사유)
```
```

---

### 6.6 공통 유틸리티 (utils.js)

**`.claude/scripts/utils.js`:**
```javascript
const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(__dirname, '..', 'state.json');

/**
 * 상태 파일 읽기
 */
function getState() {
  if (fs.existsSync(STATE_FILE)) {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  }
  return {
    retryCount: 0,
    phase: 'init',
    results: {},
    checkpoints: {},
    failedAgents: [],
    usedFallback: {}
  };
}

/**
 * 상태 파일 저장
 */
function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

/**
 * 상태 파일 삭제 (초기화)
 */
function resetState() {
  if (fs.existsSync(STATE_FILE)) {
    fs.unlinkSync(STATE_FILE);
  }
}

/**
 * 체크포인트 저장
 */
function saveCheckpoint(name) {
  const state = getState();
  state.checkpoints[name] = {
    timestamp: Date.now(),
    phase: state.phase,
    results: { ...state.results }
  };
  saveState(state);
  console.log(`[Checkpoint] ${name} 저장됨`);
}

/**
 * 체크포인트로 롤백
 */
function rollback(checkpointName) {
  const state = getState();
  const cp = state.checkpoints[checkpointName];
  if (cp) {
    state.phase = cp.phase;
    state.results = { ...cp.results };
    saveState(state);
    console.log(`[Rollback] ${checkpointName}으로 복구됨`);
    return true;
  }
  console.error(`[Rollback] ${checkpointName} 체크포인트 없음`);
  return false;
}

/**
 * Hook 입력 파싱
 */
function getHookInput() {
  return JSON.parse(process.env.CLAUDE_TOOL_INPUT || '{}');
}

/**
 * Hook 출력 가져오기
 */
function getHookOutput() {
  return process.env.CLAUDE_TOOL_OUTPUT || '';
}

/**
 * 도구 이름 가져오기
 */
function getToolName() {
  return process.env.CLAUDE_TOOL_NAME || '';
}

module.exports = {
  getState,
  saveState,
  resetState,
  saveCheckpoint,
  rollback,
  getHookInput,
  getHookOutput,
  getToolName,
  STATE_FILE
};
```

**사용 예시:**
```javascript
// 다른 스크립트에서 사용
const { getState, saveState, getHookInput, getHookOutput } = require('./utils');

const state = getState();
const input = getHookInput();
const output = getHookOutput();

// 로직 수행
state.retryCount++;
saveState(state);
```

---

### 6.7 Skill에서 사용 가능한 도구 목록

`allowed-tools` 필드에 지정 가능한 도구:

| 도구 | 설명 |
|------|------|
| `Read` | 파일 읽기 |
| `Write` | 파일 쓰기 |
| `Edit` | 파일 수정 |
| `Glob` | 파일 패턴 검색 |
| `Grep` | 내용 검색 |
| `Bash` | 셸 명령 실행 |
| `Task` | Agent 호출 |
| `WebFetch` | 웹 페이지 가져오기 |
| `WebSearch` | 웹 검색 |

**예시:**
```yaml
---
name: my-skill
allowed-tools: Task, Read, Write, Bash
---
```

---

## 7. 한계점 및 확장

### 7.1 Claude Code CLI 한계

| 한계 | 설명 |
|------|------|
| Agent 내부 제어 불가 | Agent 실행 중에는 개입 불가, 결과만 받음 |
| Hook 필터링 수동 | 스크립트에서 직접 컨텍스트 판단 필요 |
| 상태 관리 파일 기반 | 복잡한 상태는 관리 어려움 |
| 프롬프트 의존 | Skill 지시를 Claude가 해석, 100% 보장 아님 |

### 7.2 Agent SDK로 전환 시점

다음 경우 Agent SDK (Python/TypeScript) 고려:

- **정밀한 제어 필요**: 반복, 분기를 코드로 완전 제어
- **복잡한 상태 관리**: 메모리, DB 연동
- **외부 시스템 통합**: API, 웹훅 등
- **프로덕션 배포**: 안정성, 모니터링 필요

```python
# Agent SDK 예시
from claude_agent_sdk import query

async def controlled_workflow():
    for i in range(3):  # 정확히 3회
        result = await run_agent("analyzer")
        if validate(result):
            break
    return result
```

### 7.3 MCP로 확장

MCP(Model Context Protocol)를 연동하면:

- 외부 DB 조회
- API 호출
- 슬랙/이메일 알림
- 커스텀 도구 추가

**별도 가이드 참조**: `claude_mcp_guide.md` (예정)

---

## 요약

| 구성 요소 | 역할 |
|----------|------|
| **Skill** | 오케스트레이터, 워크플로우 정의 |
| **Agent** | 독립된 작업자, 전문 영역 담당 |
| **Hook** | 시스템 레벨 제어, 검증/분기/반복 |
| **Script** | Hook의 실제 로직, 상태 관리 |

**핵심 공식:**
```
신뢰할 수 있는 워크플로우 = Skill (진입점) + Agent (작업자) + Hook (제어) + Script (로직)
```

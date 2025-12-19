# 작업 대기열 (Task Queue)

여러 작업을 대기열에 추가하고 순차적으로 처리합니다.

---

## 현재 진행 중

### 🟢 IN_PROGRESS
- **작업 ID**: `task-001`
- **제목**: 로그인 기능 구현
- **폴더**: `tasks/task-001-login/`
- **담당**: Claude Code
- **상태**: Codex 리뷰 대기중
- **시작**: 2025-12-19 16:45

---

## 대기 중인 작업

### 1. ⏸️ QUEUED - 결제 기능 추가
- **작업 ID**: `task-002`
- **우선순위**: 높음
- **예상 복잡도**: 중간
- **폴더**: `tasks/task-002-payment/`
- **리뷰 레벨**: CRITICAL_ONLY
- **추가일**: 2025-12-19 17:00

### 2. ⏸️ QUEUED - API 리팩토링
- **작업 ID**: `task-003`
- **우선순위**: 보통
- **예상 복잡도**: 높음
- **폴더**: `tasks/task-003-refactor/`
- **리뷰 레벨**: STANDARD
- **추가일**: 2025-12-19 17:10

### 3. ⏸️ QUEUED - 버그 수정 (#234)
- **작업 ID**: `task-004`
- **우선순위**: 긴급
- **예상 복잡도**: 낮음
- **폴더**: `tasks/task-004-bugfix-234/`
- **리뷰 레벨**: CRITICAL_ONLY
- **추가일**: 2025-12-19 17:15

---

## 완료된 작업

### ✅ COMPLETED - 회원가입 폼 (task-000)
- **완료일**: 2025-12-19 16:30
- **리뷰 결과**: APPROVED
- **보관 위치**: `archive/20251219-1630-signup/`

---

## 작업 추가 방법

### 옵션 A: 수동 추가
1. 이 파일 편집
2. "대기 중인 작업" 섹션에 새 항목 추가
3. `tasks/task-XXX-name/` 폴더 생성
4. 그 안에 `task.md` 작성

### 옵션 B: 명령어 사용
```bash
# Claude Code에게
"새 작업 추가: 결제 기능 구현, 우선순위 높음, CRITICAL_ONLY"
```

---

## 우선순위 규칙

1. **긴급** - 버그 수정, 보안 이슈
2. **높음** - 핵심 기능
3. **보통** - 일반 기능
4. **낮음** - 개선 사항

**긴급 작업은 현재 작업 완료 후 즉시 처리됩니다.**

---

## 멀티 세션 작업 분배

### Claude Code 세션 1
- 담당: task-001 (로그인)
- 상태: Codex 리뷰 대기

### Claude Code 세션 2
- 담당: task-002 (결제)
- 상태: 구현 중

### Codex 세션 1
- 담당: task-001 리뷰
- 상태: 리뷰 중

### Codex 세션 2
- 대기: task-002 완료 대기

**주의**: 같은 파일을 동시에 수정하는 작업은 순차 처리!

---

## 작업 흐름 자동화

### status.json 기반
각 AI는 자신의 작업 폴더에서 status.json을 확인:

```json
{
  "task_id": "task-001",
  "status": "WAITING_FOR_CODEX_REVIEW",
  "current_turn": "codex",
  "last_actor": "claude-session-1",
  "timestamp": "2025-12-19T17:45:00Z"
}
```

### Claude의 체크 루프
```
1. QUEUE.md 확인 → 내 담당 작업 찾기
2. tasks/my-task/status.json 확인
3. current_turn == "claude"면 작업 시작
4. 작업 완료 → status.json 업데이트 (turn: "codex")
5. 5초 대기 후 1번으로
```

### Codex의 체크 루프
```
1. QUEUE.md 확인 → 리뷰 대기 작업 찾기
2. tasks/pending-review/status.json 확인
3. current_turn == "codex"면 리뷰 시작
4. 리뷰 완료 → status.json 업데이트 (turn: "claude" or "completed")
5. 5초 대기 후 1번으로
```

---

## 충돌 방지 규칙

### ✅ 안전한 병렬 작업
- 서로 다른 파일 수정
- 서로 다른 모듈/기능
- 독립적인 작업

### ⚠️ 순차 처리 필요
- 같은 파일 수정
- 의존성 있는 작업
- 하나가 다른 하나의 결과 필요

**예시:**
```
✅ 병렬 가능:
- Claude 1: 로그인 기능 (auth/login.js)
- Claude 2: 결제 기능 (payment/checkout.js)

❌ 병렬 불가:
- Claude 1: auth.js 수정
- Claude 2: auth.js 리팩토링
→ 순차 처리!
```

---

## 현재 세션 할당

| 세션 | 담당 작업 | 상태 |
|------|----------|------|
| Claude-1 | task-001 | Codex 리뷰 대기 |
| Claude-2 | 대기 중 | - |
| Codex-1 | task-001 리뷰 | 리뷰 중 |
| Codex-2 | 대기 중 | - |

---

## 다음 작업 자동 할당

task-001 완료 시:
1. Claude-1: task-002 시작
2. Codex-1: 대기
3. task-002 완료 후 Codex-1이 리뷰

긴급 작업(task-004) 추가 시:
1. 현재 작업 완료까지 대기
2. 완료 즉시 task-004를 큐 맨 앞으로
3. Claude-2에 할당

# 세션 메모리 (Session Memory)

이 파일은 이 대화 세션에서 만든 모든 결정사항과 이유를 기록합니다.
**새 세션 시작 시 이 파일을 먼저 읽으세요!**

---

## 📅 생성 일자
2025-12-19

---

## 🎯 프로젝트 목표

사용자가 Claude Code와 Codex를 협업시켜서:
1. **Claude Code**: 모든 코드 작성/수정 (저렴한 사용량)
2. **Codex**: 코드 리뷰만 (비싼 사용량 절약)
3. **턴 기반**: 서로 작업 → 문서 작성 → 대기 → 상대방 작업
4. **다중 작업**: 여러 기능을 동시/순차 처리

---

## 🔑 핵심 인사이트

### 사용자의 실제 요구사항
1. **자율 동작**: AI들이 서로 문서 보고 알아서 작업
2. **비동기**: 사용자가 왔다갔다 하는 게 아님
3. **비용 효율**: Codex는 리뷰만, Claude는 모든 작업
4. **다중 작업**: 프로젝트에는 수많은 기능 필요
5. **멀티 세션**: Claude 2개 + Codex 2개 병렬 가능한지?

### 현실적 제약사항
1. **완전 자동화 불가**: Claude Code는 데몬이 아님
2. **파일 감시 불가**: 백그라운드에서 자동 체크 못함
3. **세션 간 통신 불가**: 각 AI는 독립적
4. **반자동화가 최선**: 사용자가 턴 전환 필요

---

## 📁 최종 파일 구조

```
.ai-collab/
├── SESSION-MEMORY.md        # 이 파일! (새 세션 시 필독)
├── SETUP-GUIDE.md           # 실전 사용 가이드 (여기서 시작)
├── CLAUDE-GUIDE.md          # Claude 역할/워크플로우
├── CODEX-GUIDE.md           # Codex 리뷰 가이드라인
├── watch-status.ps1         # Windows 상태 모니터
├── watch-status.sh          # Linux/Mac 상태 모니터
├── tasks/
│   ├── TASK-TEMPLATE/       # 작업 템플릿
│   │   ├── task.md
│   │   └── status.json
│   └── task-XXX-name/       # 실제 작업들
│       ├── task.md          # 작업 설명
│       ├── status.json      # 현재 턴 추적
│       ├── claude-work.md   # Claude 작업 로그
│       └── codex-review.md  # Codex 리뷰 결과
├── archive/                 # 완료된 작업
├── QUEUE.md                 # 다중 작업 관리 (옵션)
├── README.md                # 이상적 워크플로우 (참고용)
└── current-task/            # 단순 작업용 (옵션)
```

---

## 🔄 워크플로우 (확정)

### 실제 동작 방식
```
1. 사용자: tasks/task-XXX 폴더 생성 + task.md + status.json
2. 사용자 → Claude: "tasks/task-XXX 작업해줘"
3. Claude: 코드 작성 → claude-work.md → status.json (turn: codex)
4. 사용자 → Codex: "tasks/task-XXX 리뷰해줘"
5. Codex: 리뷰 → codex-review.md → status.json (turn: claude)
6. 사용자 → Claude: "tasks/task-XXX 수정해줘"
7. 반복... (APPROVED까지)
```

### Watch Script로 개선
```
터미널 1: watch-status.ps1 실행 (상태 대시보드)
터미널 2: Claude Code
터미널 3: Codex

→ Watch Script가 10초마다 업데이트
→ "🔵 task-001 Claude 차례" 표시
→ 사용자가 해당 터미널에서 명령 실행
```

---

## 📄 핵심 파일 설명

### 1. task.md (사용자 작성)
```markdown
# Task: [작업명]

## 요구사항
- 구체적 요구사항

## 리뷰 레벨
CRITICAL_ONLY / STANDARD / THOROUGH
```

### 2. status.json (AI가 업데이트)
```json
{
  "current_turn": "claude" | "codex" | "completed",
  "status": "QUEUED | IN_PROGRESS | WAITING_FOR_CODEX_REVIEW | REVISION_NEEDED | APPROVED",
  "last_actor": "claude" | "codex",
  "timestamp": "2025-12-19T18:00:00Z"
}
```

### 3. claude-work.md (Claude 작성)
- 변경된 파일 목록
- 구현 내용
- 자체 체크리스트
- Codex에게 요청사항 (리뷰 레벨, 중점 사항)

### 4. codex-review.md (Codex 작성)
- 🔴 Critical Issues (필수 수정)
- ⚠️ Warnings (권장 수정)
- 📝 Suggestions (선택)
- Decision: APPROVED / REVISION_NEEDED / MAJOR_ISSUES

---

## 🎚️ 리뷰 레벨

### CRITICAL_ONLY (기본, 권장)
- 보안 취약점 (SQL injection, XSS, etc.)
- 런타임 에러
- 로직 버그
- **무시**: 코드 스타일, 변수명, 주석

### STANDARD
- 위 항목 + 에러 핸들링, 엣지 케이스

### THOROUGH
- 모든 것 (비쌈, 특별한 경우만)

---

## 🔢 멀티 세션 전략

### 질문: Claude 2개 + Codex 2개 문제?
**답: 문제 없음, 단 충돌 주의**

```
✅ 병렬 가능:
- Claude-1: auth/login.js
- Claude-2: payment/checkout.js
→ 다른 파일, 독립적

❌ 병렬 불가:
- Claude-1: utils.js 수정
- Claude-2: utils.js 리팩토링
→ 같은 파일, 충돌!
```

### 전략
1. tasks/ 폴더에 여러 작업 생성
2. status.json에 세션 할당 명시
   ```json
   {
     "assigned_to": "claude-session-1",
     "reviewer": "codex-session-1"
   }
   ```
3. 충돌 없는 작업만 병렬 처리

---

## 💡 중요 결정 사항

### 1. 완전 자동화 포기
**이유**: Claude Code는 파일 감시 불가, 사용자 명령 필요
**해결**: 반자동 + Watch Script로 상태 추적

### 2. 단순한 구조 선택
**이유**: 복잡하면 오히려 혼란
**선택**: tasks/ 폴더 + status.json + 3개 md 파일

### 3. Git 활용 최소화
**이유**: 모든 사용자가 Git 능숙하지 않음
**선택**: 파일 기반 협업, Git은 옵션

### 4. 리뷰 레벨 기본값 CRITICAL_ONLY
**이유**: Codex 비용 절약, 대부분의 경우 충분
**효과**: 빠르고 저렴

---

## 🚫 삭제/변경된 내용

### 삭제한 것들
- "5초마다 자동 체크" → 불가능
- "AI 간 자동 통신" → 불가능
- "완전 자율 동작" → 현실적으로 불가

### 남긴 것들
- README.md (이상적 워크플로우, 참고용)
- QUEUE.md (다중 작업 관리, 옵션)
- current-task/ (단순 작업용, 옵션)

**실제 사용은 SETUP-GUIDE.md 참고!**

---

## 🎯 사용자 타입별 추천

### 타입 1: 단순 사용자
```
- tasks/ 폴더에 1개 작업만
- Claude → Codex → Claude 순차
- watch-status 안 써도 됨
```

### 타입 2: 중급 사용자
```
- tasks/ 폴더에 3-5개 작업
- watch-status.ps1 사용
- 순차 처리
```

### 타입 3: 고급 사용자
```
- 여러 작업 동시 진행
- Claude 2개 + Codex 2개
- QUEUE.md로 관리
- 충돌 주의하며 병렬 처리
```

---

## 📞 자주 쓰는 명령어

### Claude에게
```
"CLAUDE-GUIDE.md 읽고 tasks/task-001-login 작업해줘"
"tasks/task-001-login 리뷰 반영해줘"
"tasks/task-001-login status.json을 completed로 바꿔줘"
```

### Codex에게
```
"CODEX-GUIDE.md 읽고 tasks/task-001-login 리뷰해줘"
"tasks/task-001-login 재확인해줘"
"tasks/task-001-login APPROVED 처리해줘"
```

---

## 🆘 알려진 문제 및 해결

### 문제 1: status.json 업데이트 안 됨
**해결**: AI에게 명시적으로 요청
```
"status.json을 다음으로 업데이트해줘:
{\"current_turn\": \"codex\", \"status\": \"WAITING_FOR_CODEX_REVIEW\"}"
```

### 문제 2: 무한 루프 (계속 수정 요청)
**해결**: 수동 승인
```json
{
  "current_turn": "completed",
  "status": "APPROVED",
  "note": "수동 승인 - 충분히 개선됨"
}
```

### 문제 3: Codex 비용 과다
**해결**: task.md에 명시
```markdown
## 리뷰 레벨: CRITICAL_ONLY
## 리뷰하지 마세요
- 코드 스타일, 변수명, 주석
```

---

## 🔮 미래 개선 가능성

### 옵션 1: MCP (Model Context Protocol)
- Claude Desktop이 MCP 지원하면
- 파일 감시 서버 만들기 가능
- 완전 자동화 가능

### 옵션 2: VS Code Extension
- 확장 프로그램 개발
- 버튼 클릭으로 턴 전환
- GUI로 상태 관리

### 옵션 3: GitHub Actions
- PR 생성 시 자동 리뷰 트리거
- Codex API 호출
- 자동 코멘트

**현재로서는 반자동이 최선!**

---

## 📝 다음 세션에서 할 일

새 세션 시작 시:

1. **이 파일 먼저 읽기** (SESSION-MEMORY.md)
2. SETUP-GUIDE.md 확인
3. 사용자 요구사항 확인
4. 기존 구조 유지하며 개선

### 변경 금지 사항
- ❌ 완전 자동화 시도 (불가능)
- ❌ 복잡한 구조 추가
- ❌ 기본 워크플로우 변경

### 개선 가능 사항
- ✅ 문서 개선 (더 명확하게)
- ✅ 예시 추가
- ✅ 버그 수정
- ✅ 새 헬퍼 스크립트

---

## 🎓 배운 점

1. **이상 vs 현실**: 이상적 설계보다 현실적 실행이 중요
2. **단순함**: 복잡한 시스템보다 단순한 시스템이 더 잘 작동
3. **문서화**: AI 협업은 명확한 가이드 필수
4. **역할 분리**: Claude=코딩, Codex=리뷰로 명확히
5. **비용 의식**: Codex는 CRITICAL_ONLY로 비용 절약

---

## ✅ 최종 체크리스트

### 완료된 것들
- [x] 파일 구조 생성
- [x] Claude/Codex 가이드 작성
- [x] Watch Script 구현 (Windows + Linux)
- [x] 실전 설정 가이드 (SETUP-GUIDE.md)
- [x] 세션 메모리 문서 (이 파일)
- [x] 작업 템플릿
- [x] 다중 작업 관리 방법
- [x] 멀티 세션 전략

### 사용자가 할 일
- [ ] SETUP-GUIDE.md 읽기
- [ ] 첫 작업 만들어보기
- [ ] Watch Script 테스트
- [ ] 실제 프로젝트에 적용

---

## 🌟 핵심 요약 (30초 버전)

```
목적: Claude(코딩) + Codex(리뷰) 협업
구조: tasks/ 폴더 + status.json + 3개 md 파일
방식: 반자동 (사용자가 턴 전환)
도구: watch-status 스크립트로 상태 추적
비용: CRITICAL_ONLY 리뷰로 절약
확장: 멀티 세션 가능 (충돌 주의)
시작: SETUP-GUIDE.md 읽고 바로 사용!
```

**이 시스템은 실제로 작동합니다! 🚀**

---

**마지막 업데이트**: 2025-12-19
**작성자**: Claude Code (Sonnet 4.5)
**세션 ID**: [현재 세션]

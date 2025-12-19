# Claude Code 역할 가이드

## Quick Start 명령어
- 새 작업: `"task.md 읽고 시작해"`
- 리뷰 반영: `"codex-review.md 반영해"`
- 상태 확인: `"현재 상태 알려줘"`

---

## 당신의 역할
당신은 **구현 담당 AI**입니다. 모든 코딩 작업을 담당합니다.

### 담당 업무
- ✅ 코드 작성 및 수정
- ✅ 버그 수정
- ✅ 기능 구현
- ✅ 리팩토링
- ✅ Codex 리뷰 반영

### 담당하지 않는 업무
- ❌ 코드 리뷰 (Codex 전담)
- ❌ 과도한 자체 검증
- ❌ 리뷰 없이 완료 처리

---

## 작업 흐름

### 1단계: 새 작업 시작
1. `current-task/task.md` 파일 읽기
2. 작업 내용 파악
3. 코드 작성/수정 진행
4. 완료 후 `current-task/claude-work.md` 작성

### 2단계: 작업 결과 문서화 (claude-work.md)

**템플릿:**
```markdown
## 작업 완료
날짜: 2025-12-19 16:45
상태: WAITING_FOR_CODEX_REVIEW

## 변경된 파일
- src/auth/login.js (신규 생성)
- src/routes/app.js (라우트 추가, 라인 45-52)
- src/middleware/auth.js (수정, JWT 검증 추가)

## 구현 내용
- 사용자 로그인 기능 구현
- JWT 토큰 기반 인증
- 세션 관리 추가
- bcrypt로 비밀번호 해싱

## 자체 체크리스트
- [x] 기본 동작 테스트 완료
- [x] 에러 핸들링 추가
- [x] 보안 고려사항 반영 (bcrypt, JWT)
- [x] 기존 코드와 충돌 없음 확인

## Codex에게 요청
리뷰 레벨: CRITICAL_ONLY

다음 항목을 중점적으로 확인해주세요:
- 보안 취약점 (SQL injection, XSS 등)
- 로직 오류
- 런타임 에러 가능성
- 인증/인가 관련 보안 이슈

다음은 리뷰하지 않아도 됩니다:
- 코드 스타일
- 변수명
- 주석
```

### 3단계: Codex 리뷰 대기
- `claude-work.md` 작성 후 사용자에게 알림
- **"Codex 리뷰 준비 완료. Codex 창에서 리뷰 시작해주세요."**
- 대기 상태 유지

### 4단계: 리뷰 반영
1. `current-task/codex-review.md` 읽기
2. 이슈 분류에 따라 처리:
   - 🔴 **Critical Issues**: **반드시 수정** (보안, 버그, 로직 오류)
   - ⚠️ **Warnings**: 판단 후 수정 (중요하지만 치명적이지 않음)
   - 📝 **Suggestions**: 선택적 수정 (시간이 있으면)

3. 수정 완료 후 `claude-work.md` 업데이트:
```markdown
## 수정 완료 (2차)
날짜: 2025-12-19 17:10
상태: WAITING_FOR_CODEX_REVIEW

## Codex 리뷰 반영 내역
### Critical Issues 수정
- [x] login.js:15 - SQL injection 방지 (prepared statement 사용)
- [x] login.js:23 - 비밀번호 해싱 추가 (bcrypt)

### Warnings 수정
- [x] app.js:8 - 에러 핸들링 추가

### Suggestions
- [ ] 변수명 개선 (낮은 우선순위로 패스)

## 재리뷰 요청
모든 Critical 이슈 수정 완료. 최종 확인 부탁드립니다.
```

### 5단계: 반복
- Codex가 `APPROVED` 할 때까지 3-4단계 반복
- 승인 후 `current-task/` 폴더를 `archive/YYYYMMDD-HHMM-작업명/`으로 이동

---

## 리뷰 레벨 설명

### CRITICAL_ONLY (기본, 권장)
- 보안 취약점
- 런타임 에러
- 로직 버그
- 데이터 손실 가능성

### STANDARD
- 위 항목 +
- 에러 핸들링
- 엣지 케이스
- 성능 이슈

### THOROUGH
- 모든 항목 +
- 코드 스타일
- 리팩토링 제안
- 문서화

**권장:** 대부분의 경우 `CRITICAL_ONLY`로 충분합니다. Codex 비용 절약을 위해 필요한 것만 요청하세요.

---

## 절대 규칙

### ✅ 해야 할 것
1. 항상 `claude-work.md` 작성
2. Codex Critical 이슈는 100% 수정
3. 수정 후 반드시 재리뷰 요청
4. 파일 경로와 라인 번호 명확히 기록

### ❌ 하지 말아야 할 것
1. Codex 역할 대신하기 (리뷰는 Codex만)
2. 리뷰 없이 작업 완료 처리
3. Critical 이슈 무시하고 진행
4. 과도한 자체 리뷰로 시간 낭비

---

## 파일 구조

```
.ai-collab/
├── CLAUDE-GUIDE.md          # 이 파일
├── CODEX-GUIDE.md           # Codex용 가이드
├── current-task/
│   ├── task.md              # 사용자 작업 지시
│   ├── claude-work.md       # 당신이 작성
│   └── codex-review.md      # Codex가 작성
└── archive/
    └── 20251219-1645-login/ # 완료된 작업들
```

---

## 예시 시나리오

**사용자 요청:**
> "로그인 기능 추가해줘"

**당신의 작업:**
1. `task.md` 읽음
2. 코드 작성 (login.js, app.js 수정)
3. `claude-work.md` 작성
4. 사용자에게: "작업 완료. Codex 리뷰 준비됨."

**Codex 리뷰 후:**
1. `codex-review.md` 읽음
2. Critical 2개 발견
3. 수정 후 `claude-work.md` 업데이트
4. 사용자에게: "수정 완료. 재리뷰 요청."

**Codex 승인 후:**
1. 폴더를 archive로 이동
2. 사용자에게: "작업 완료 및 승인됨. ✅"

---

## 문제 해결

### Q: Codex 리뷰 파일이 없어요
A: 사용자가 아직 Codex 창에서 리뷰를 시작하지 않았습니다. 대기하세요.

### Q: Critical 이슈가 이해가 안 가요
A: 사용자에게 질문하세요. "Codex가 지적한 SQL injection 이슈의 의도를 명확히 알고 싶습니다."

### Q: Suggestion은 꼭 해야 하나요?
A: 아니요. Critical만 필수입니다. 시간이 있으면 Warning, Suggestion은 선택입니다.

---

## 시작 시 체크리스트
- [ ] 이 가이드 전체 읽음
- [ ] `current-task/task.md` 확인
- [ ] 파일 구조 이해
- [ ] 리뷰 레벨 이해

**준비되면 작업 시작하세요!**

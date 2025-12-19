# 실전 설정 가이드 (SETUP GUIDE)

이 문서는 실제로 시스템을 사용하는 방법을 단계별로 설명합니다.

---

## 🎯 현실 체크

### ❌ 불가능한 것들
- AI가 자동으로 파일 감시 (Claude Code는 데몬이 아님)
- 세션 간 자동 통신
- 완전 자동화된 워크플로우

### ✅ 가능한 것들
- 체계적인 작업 분리 (Claude = 코딩, Codex = 리뷰)
- 문서 기반 협업
- 상태 추적 및 관리
- **반자동화** (사용자가 턴 전환)

---

## 🚀 실전 사용법

### 방법 1: 기본 워크플로우 (가장 단순)

#### 준비
```bash
# 1. 2개 터미널/창 열기
터미널 1: Claude Code
터미널 2: Codex
```

#### 사용
```
1. [사용자] 작업 생성
   mkdir .ai-collab/tasks/task-001-login
   vim .ai-collab/tasks/task-001-login/task.md

2. [터미널 1 - Claude]
   "CLAUDE-GUIDE.md 읽고 tasks/task-001-login 작업해줘"

3. [Claude 작업 완료 후]
   → claude-work.md 작성됨
   → status.json 업데이트 (turn: codex)

4. [터미널 2 - Codex]
   "CODEX-GUIDE.md 읽고 tasks/task-001-login 리뷰해줘"

5. [Codex 리뷰 완료 후]
   → codex-review.md 작성됨
   → status.json 업데이트 (turn: claude)

6. [터미널 1 - Claude]
   "tasks/task-001-login 리뷰 반영해줘"

7. [수정 완료 후]
   → status.json 업데이트 (turn: codex)

8. [터미널 2 - Codex]
   "tasks/task-001-login 재리뷰해줘"

9. [Codex 승인 시]
   → status.json: "completed", "APPROVED"

10. 완료! 🎉
```

**장점:**
- 실제로 작동함
- 각 단계 확인 가능
- 간단함

**단점:**
- 수동 전환 필요

---

### 방법 2: Watch Script 활용 (권장)

#### 준비
```bash
# 1. 3개 터미널 열기
터미널 1: Watch Script (상태 모니터)
터미널 2: Claude Code
터미널 3: Codex

# 터미널 1에서
cd c:\Temp\store
.\\.ai-collab\watch-status.ps1   # Windows
# 또는
bash .ai-collab/watch-status.sh  # Linux/Mac
```

#### 사용
```
터미널 1 (Watch Script):
=== AI 협업 상태 대시보드 ===
🔵 task-001-login - Claude 차례
   → Claude 창에서 실행: 'tasks/task-001-login 작업 시작해'

터미널 2 (Claude):
> "tasks/task-001-login 작업 시작해"
[작업 진행...]
[완료]

터미널 1 (10초 후 자동 업데이트):
🟢 task-001-login - Codex 차례
   → Codex 창에서 실행: 'tasks/task-001-login 리뷰해'

터미널 3 (Codex):
> "tasks/task-001-login 리뷰해"
[리뷰 진행...]
[완료]

... 반복
```

**장점:**
- 실시간 상태 확인
- 다음 할 일 명확
- 여러 작업 동시 추적

---

### 방법 3: Git Commit Hook (고급)

#### 설정
```bash
# .git/hooks/post-commit
#!/bin/bash
MSG=$(git log -1 --pretty=%B)

if [[ $MSG == *"CODEX_REVIEW"* ]]; then
    echo "=============================="
    echo "🟢 Codex 리뷰 필요!"
    echo "Codex 창으로 이동하세요"
    echo "=============================="
fi

if [[ $MSG == *"CLAUDE_FIX"* ]]; then
    echo "=============================="
    echo "🔵 Claude 수정 필요!"
    echo "Claude 창으로 이동하세요"
    echo "=============================="
fi
```

#### 사용
```bash
# Claude가 작업 완료 후
git commit -m "feat: login 구현 [CODEX_REVIEW]"
# → Hook이 자동으로 "Codex 리뷰 필요!" 출력

# Codex가 리뷰 완료 후
git commit -m "review: 2개 critical 이슈 발견 [CLAUDE_FIX]"
# → Hook이 "Claude 수정 필요!" 출력
```

---

## 📊 다중 작업 관리

### 현실적인 접근

#### 시나리오: 3개 작업 진행

```
작업 1: 로그인 (Claude-1, Codex-1)
작업 2: 결제 (Claude-1, Codex-1) - 작업 1 완료 후
작업 3: 프로필 (Claude-1, Codex-1) - 작업 2 완료 후
```

**순차 처리:**
```
09:00 - task-001 시작 (Claude)
09:20 - task-001 리뷰 (Codex)
09:25 - task-001 수정 (Claude)
09:30 - task-001 승인 (Codex) ✅

09:30 - task-002 시작 (Claude)
09:50 - task-002 리뷰 (Codex)
...
```

#### 병렬 처리 (Claude 2개 사용)

```
터미널 1: Claude-1
터미널 2: Claude-2
터미널 3: Codex
터미널 4: Watch Script
```

**동시 진행:**
```
09:00 - Claude-1: task-001 (auth/login.js)
09:00 - Claude-2: task-002 (payment/checkout.js)  # 다른 파일!

09:20 - Codex: task-001 리뷰
09:25 - Claude-1: task-001 수정

09:25 - Codex: task-002 리뷰  # task-001 끝나고
09:30 - Claude-2: task-002 수정
```

**주의:** 같은 파일 수정하는 작업은 순차 처리!

---

## 🗂️ 파일 구조 단순화

### 실제로 필요한 것만

```
.ai-collab/
├── SETUP-GUIDE.md          # 이 파일 (시작은 여기서!)
├── CLAUDE-GUIDE.md          # Claude 역할 가이드
├── CODEX-GUIDE.md           # Codex 역할 가이드
├── watch-status.ps1         # 상태 모니터 (Windows)
├── watch-status.sh          # 상태 모니터 (Linux/Mac)
├── tasks/
│   └── task-001-login/
│       ├── task.md          # 작업 설명
│       ├── status.json      # 현재 상태
│       ├── claude-work.md   # Claude 작업 로그
│       └── codex-review.md  # Codex 리뷰
└── archive/                 # 완료된 작업
```

**삭제해도 되는 것:**
- `current-task/` (tasks/ 폴더로 통합)
- `QUEUE.md` (작업 많지 않으면 불필요)
- `README.md` (이 SETUP-GUIDE로 충분)

---

## 🔧 status.json 사용법

### 최소 템플릿
```json
{
  "current_turn": "claude",
  "status": "QUEUED"
}
```

### 전체 템플릿
```json
{
  "task_id": "task-001-login",
  "status": "WAITING_FOR_CODEX_REVIEW",
  "current_turn": "codex",
  "last_actor": "claude",
  "created_at": "2025-12-19T18:00:00Z",
  "updated_at": "2025-12-19T18:15:00Z"
}
```

### 상태 전환
```
QUEUED (초기)
  ↓ (Claude 시작)
IN_PROGRESS (Claude 작업 중)
  ↓ (Claude 완료)
WAITING_FOR_CODEX_REVIEW (turn: codex)
  ↓ (Codex 리뷰)
REVISION_NEEDED (turn: claude, critical 이슈 발견)
  ↓ (Claude 수정)
WAITING_FOR_CODEX_REVIEW (turn: codex, 재리뷰)
  ↓ (Codex 승인)
APPROVED (turn: completed) ✅
```

---

## 💡 실전 팁

### 1. 작업 크기 조절
```
✅ 좋은 크기: 1-2시간 작업
   - 로그인 폼 추가
   - API 엔드포인트 1개
   - 버그 수정 1건

❌ 너무 큼: 1일+ 작업
   - 전체 인증 시스템
   - API 전체 재설계
   → 여러 작업으로 분할!
```

### 2. 리뷰 레벨 선택
```
일반 작업: CRITICAL_ONLY (빠르고 저렴)
중요 기능: STANDARD (균형)
배포 전: THOROUGH (꼼꼼하지만 비쌈)
```

### 3. 명령어 단축
```bash
# .bashrc 또는 .zshrc에 추가
alias claude-start='cd c:/Temp/store && claude-code'
alias codex-start='cd c:/Temp/store && codex'
alias watch-ai='cd c:/Temp/store && ./.ai-collab/watch-status.sh'
```

### 4. 작업 템플릿 활용
```bash
# 새 작업 빠르게 생성
function new-task() {
  task_name=$1
  cp -r .ai-collab/tasks/TASK-TEMPLATE .ai-collab/tasks/$task_name
  vim .ai-collab/tasks/$task_name/task.md
}

# 사용
new-task task-005-profile
```

---

## 🆘 문제 해결

### Q: status.json이 업데이트 안 됨
**A:** AI에게 명시적으로 요청
```
"작업 완료 후 status.json을 업데이트해줘:
{
  \"current_turn\": \"codex\",
  \"status\": \"WAITING_FOR_CODEX_REVIEW\"
}"
```

### Q: 무한 루프 (계속 수정 요청)
**A:** 수동 개입
```
# status.json 직접 수정
{
  "current_turn": "completed",
  "status": "APPROVED",
  "note": "수동 승인"
}
```

### Q: 여러 작업 헷갈림
**A:** Watch Script 사용
```powershell
.\\.ai-collab\watch-status.ps1
# 실시간으로 모든 작업 상태 확인
```

### Q: Codex 비용 너무 많이 나옴
**A:** task.md에서 CRITICAL_ONLY 명시
```markdown
## 리뷰 레벨
CRITICAL_ONLY

## 리뷰하지 마세요
- 코드 스타일
- 변수명
- 주석
```

---

## 📝 체크리스트

### 초기 설정 (1회만)
- [ ] `.ai-collab/` 폴더 구조 확인
- [ ] CLAUDE-GUIDE.md 읽기
- [ ] CODEX-GUIDE.md 읽기
- [ ] watch-status 스크립트 테스트

### 매 작업마다
- [ ] tasks/task-XXX 폴더 생성
- [ ] task.md 작성 (요구사항 명확히)
- [ ] status.json 생성 (turn: claude)
- [ ] Watch Script 실행 (옵션)
- [ ] Claude 실행
- [ ] Codex 리뷰
- [ ] 반복 (승인까지)
- [ ] archive로 이동

---

## 🎯 시작하기

### 첫 작업 만들기 (5분 안에)

```bash
# 1. 폴더 생성
mkdir .ai-collab/tasks/task-001-test

# 2. task.md 작성
cat > .ai-collab/tasks/task-001-test/task.md << 'EOF'
# Task: 간단한 테스트

## 요구사항
- console.log("Hello AI Collaboration") 추가

## 리뷰 레벨
CRITICAL_ONLY
EOF

# 3. status.json 생성
cat > .ai-collab/tasks/task-001-test/status.json << 'EOF'
{
  "current_turn": "claude",
  "status": "QUEUED"
}
EOF

# 4. Claude에게
# "CLAUDE-GUIDE.md 읽고 tasks/task-001-test 작업해줘"

# 5. 완료 후 Codex에게
# "CODEX-GUIDE.md 읽고 tasks/task-001-test 리뷰해줘"
```

---

## 🌟 핵심 정리

### 현실
1. **완전 자동화는 불가능** (AI가 데몬이 아님)
2. **반자동화가 최선** (사용자가 턴 전환)
3. **Watch Script로 상태 추적**
4. **단순한 구조가 실용적**

### 실제 워크플로우
```
사용자 → task.md 작성
사용자 → Claude 실행 ("작업해줘")
Claude → 작업 완료 → status.json 업데이트
사용자 → Codex 실행 ("리뷰해줘")
Codex → 리뷰 완료 → status.json 업데이트
사용자 → Claude 실행 ("수정해줘")
... 반복
```

### 가장 중요한 것
- ✅ 역할 분리 (Claude=코딩, Codex=리뷰)
- ✅ 문서화 (claude-work.md, codex-review.md)
- ✅ 상태 추적 (status.json)
- ✅ 체계적 관리 (tasks/ 폴더)

**이제 시작하세요! 🚀**

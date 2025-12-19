# AI 협업 상태 감시 스크립트 (Windows PowerShell)
# 사용법: .\watch-status.ps1

$TasksDir = ".ai-collab\tasks"
$CheckInterval = 10  # 10초마다 체크

Write-Host "🔍 AI 협업 상태 감시 시작..." -ForegroundColor Green
Write-Host "Ctrl+C로 종료"
Write-Host ""

while ($true) {
    Clear-Host
    Write-Host "=== AI 협업 상태 대시보드 ===" -ForegroundColor Cyan
    Write-Host "시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    # 모든 작업 폴더 확인
    $taskDirs = Get-ChildItem -Path $TasksDir -Directory -Filter "task-*" -ErrorAction SilentlyContinue

    if ($taskDirs) {
        foreach ($taskDir in $taskDirs) {
            $statusFile = Join-Path $taskDir.FullName "status.json"

            if (Test-Path $statusFile) {
                $taskName = $taskDir.Name
                $statusJson = Get-Content $statusFile -Raw | ConvertFrom-Json
                $currentTurn = $statusJson.current_turn
                $status = $statusJson.status

                # 색상 표시
                switch ($currentTurn) {
                    "claude" {
                        Write-Host "🔵 $taskName - Claude 차례 (상태: $status)" -ForegroundColor Blue
                        Write-Host "   → Claude 창에서 실행: 'tasks/$taskName 작업 시작해'" -ForegroundColor Gray
                    }
                    "codex" {
                        Write-Host "🟢 $taskName - Codex 차례 (상태: $status)" -ForegroundColor Green
                        Write-Host "   → Codex 창에서 실행: 'tasks/$taskName 리뷰해'" -ForegroundColor Gray
                    }
                    "completed" {
                        Write-Host "✅ $taskName - 완료 (상태: $status)" -ForegroundColor Green
                    }
                    default {
                        Write-Host "⏸️  $taskName - 대기 중 (상태: $status)" -ForegroundColor Yellow
                    }
                }
                Write-Host ""
            }
        }
    } else {
        Write-Host "작업 없음" -ForegroundColor Yellow
    }

    Write-Host "---" -ForegroundColor Gray
    Write-Host "다음 체크: ${CheckInterval}초 후..."
    Start-Sleep -Seconds $CheckInterval
}

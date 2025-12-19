#!/bin/bash

# AI 협업 상태 감시 스크립트
# 사용법: ./watch-status.sh

TASKS_DIR=".ai-collab/tasks"
CHECK_INTERVAL=10  # 10초마다 체크

echo "🔍 AI 협업 상태 감시 시작..."
echo "Ctrl+C로 종료"
echo ""

while true; do
    clear
    echo "=== AI 협업 상태 대시보드 ==="
    echo "시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # 모든 작업 폴더 확인
    for task_dir in "$TASKS_DIR"/task-*/; do
        if [ -f "$task_dir/status.json" ]; then
            task_name=$(basename "$task_dir")
            current_turn=$(jq -r '.current_turn' "$task_dir/status.json" 2>/dev/null || echo "unknown")
            status=$(jq -r '.status' "$task_dir/status.json" 2>/dev/null || echo "unknown")

            # 색상 표시
            if [ "$current_turn" = "claude" ]; then
                echo "🔵 $task_name - Claude 차례 (상태: $status)"
                echo "   → Claude 창에서 실행: 'tasks/$task_name 작업 시작해'"
            elif [ "$current_turn" = "codex" ]; then
                echo "🟢 $task_name - Codex 차례 (상태: $status)"
                echo "   → Codex 창에서 실행: 'tasks/$task_name 리뷰해'"
            elif [ "$current_turn" = "completed" ]; then
                echo "✅ $task_name - 완료 (상태: $status)"
            else
                echo "⏸️  $task_name - 대기 중 (상태: $status)"
            fi
            echo ""
        fi
    done

    echo "---"
    echo "다음 체크: ${CHECK_INTERVAL}초 후..."
    sleep $CHECK_INTERVAL
done

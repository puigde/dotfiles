#!/bin/bash
# tmux per-window Claude Code indicator
# Called from window-status-format with #{pane_pid}
#   ◆ = active (tools, subagents, responding, thinking)
#   ◇ = waiting for user input
PANE_PID=$1
[ -z "$PANE_PID" ] && exit 0

SESSION_DIR="$HOME/.claude/sessions"
[ ! -d "$SESSION_DIR" ] && exit 0

for session_file in "$SESSION_DIR"/*.json; do
    [ ! -f "$session_file" ] && continue
    CPID=$(basename "$session_file" .json)
    kill -0 "$CPID" 2>/dev/null || continue

    # Is this Claude a descendant of our pane? (up to 5 levels for nix-shell etc.)
    PID=$CPID FOUND=0 DEPTH=0
    while [ "$PID" -gt 1 ] && [ "$DEPTH" -lt 5 ]; do
        PID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
        [ "$PID" = "$PANE_PID" ] && { FOUND=1; break; }
        DEPTH=$((DEPTH + 1))
    done
    [ "$FOUND" -eq 0 ] && continue

    # Found our Claude. Check if active via two signals:

    # 1) Non-caffeinate child processes (tools, agents, bash, node...)
    #    ps ax is needed because tool subprocesses have no controlling terminal
    #    and pgrep -P silently skips them on macOS.
    NON_CAFF=$(ps ax -o ppid=,comm= | awk -v p="$CPID" '$1 == p && $2 != "caffeinate"' | wc -l)
    [ "$NON_CAFF" -gt 0 ] && { printf ' ◆'; exit 0; }

    # 2) Transcript recently modified (catches streaming responses, some thinking)
    SID=$(grep -o '"sessionId":"[^"]*"' "$session_file" | cut -d'"' -f4)
    CWD=$(grep -o '"cwd":"[^"]*"' "$session_file" | cut -d'"' -f4)
    if [ -n "$SID" ] && [ -n "$CWD" ]; then
        PROJECT=$(printf '%s' "$CWD" | sed 's|^/|-|' | tr '/' '-')
        TRANSCRIPT="$HOME/.claude/projects/$PROJECT/$SID.jsonl"
        if [ -f "$TRANSCRIPT" ]; then
            MOD=$(stat -f %m "$TRANSCRIPT" 2>/dev/null || echo 0)
            NOW=$(date +%s)
            [ $((NOW - MOD)) -lt 10 ] && { printf ' ◆'; exit 0; }
        fi
    fi

    printf ' ◇'
    exit 0
done

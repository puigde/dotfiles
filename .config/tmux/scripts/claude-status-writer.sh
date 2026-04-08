#!/bin/bash
# Claude Code statusLine script — TUI status bar display only
# Receives session JSON on stdin, outputs formatted text
set -euo pipefail
JSON=$(cat)
MODEL=$(printf '%s' "$JSON" | jq -r '.model.display_name // "?"')
CTX=$(printf '%s' "$JSON" | jq -r '.context_window.used_percentage // 0')
printf '%s  %s%%' "$MODEL" "$CTX"

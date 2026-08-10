#!/usr/bin/env bash
set -euo pipefail

project="${VELOGB10_PROJECT_DIR:-$HOME/velogb10-qwen35-full-tp2}"
pidfile="$project/run/tp-head.pid"
if [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null; then
  printf 'managed TP head: running (pid %s)\n' "$(<"$pidfile")"
else
  echo 'managed TP head: not running'
fi
ss -ltn | grep ':8892 ' || true
curl --fail --silent --show-error http://127.0.0.1:8892/v1/models || true

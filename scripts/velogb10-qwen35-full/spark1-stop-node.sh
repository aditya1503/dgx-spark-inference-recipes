#!/usr/bin/env bash
set -euo pipefail

project="${VELOGB10_PROJECT_DIR:-$HOME/velogb10-qwen35-full-tp2}"
binary="$project/bin/velogb10/gb10_inference"
pidfile="$project/run/tp-node.pid"

if [[ -f "$pidfile" ]]; then
  pid="$(<"$pidfile")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "Stopped managed TP supervisor pid $pid."
  fi
fi

mapfile -t child_pids < <(pgrep -f "^$binary --node --once --port 29500$" || true)
for child_pid in "${child_pids[@]}"; do
  kill "$child_pid"
  echo "Stopped managed TP child pid $child_pid."
done

rm -f "$pidfile"

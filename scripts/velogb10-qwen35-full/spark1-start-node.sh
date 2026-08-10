#!/usr/bin/env bash
set -euo pipefail

project="${VELOGB10_PROJECT_DIR:-$HOME/velogb10-qwen35-full-tp2}"
binary="$project/bin/velogb10/gb10_inference"
pidfile="$project/run/tp-node.pid"
logfile="$project/logs/tp-node.log"

mkdir -p "$project/run" "$project/logs"
if ! ibv_devinfo -d rocep1s0f1 | grep -q 'active_mtu:[[:space:]]*4096'; then
  echo "ERROR: rocep1s0f1 active MTU is not 4096. Refusing to start TP node."
  exit 1
fi
if [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null; then
  echo "TP node is already running (pid $(<"$pidfile"))."
  exit 0
fi

cd "$project/bin/velogb10"
nohup "$binary" --node --port 29500 --rdma-dev rocep1s0f1 >"$logfile" 2>&1 &
printf '%s\n' "$!" >"$pidfile"
sleep 2
kill -0 "$(<"$pidfile")"
printf 'TP node started: pid=%s log=%s\n' "$(<"$pidfile")" "$logfile"

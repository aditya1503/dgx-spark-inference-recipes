#!/usr/bin/env bash
set -euo pipefail

project="${VELOGB10_PROJECT_DIR:-$HOME/velogb10-qwen35-full-tp2}"
peer_ip="${VELOGB10_PEER_IP:-10.200.1.1}"
binary="$project/bin/velogb10/gb10_inference"
model="$project/model"
pidfile="$project/run/tp-head.pid"
logfile="$project/logs/tp-head.log"

mkdir -p "$project/run" "$project/logs"
if ! ibv_devinfo -d rocep1s0f1 | grep -q 'active_mtu:[[:space:]]*4096'; then
  echo "ERROR: rocep1s0f1 active MTU is not 4096. Refusing to start TP head."
  exit 1
fi
if [[ -f "$pidfile" ]] && kill -0 "$(<"$pidfile")" 2>/dev/null; then
  echo "TP head is already running (pid $(<"$pidfile"))."
  exit 0
fi

cd "$project/bin/velogb10"
nohup "$binary" --server --model-dir "$model" \
  --model-name qwen35-9b-nvfp4-full-tp2 \
  --tp --nodes "$peer_ip:29500" --rdma-dev rocep1s0f1 \
  --port 8892 --max-seq-len 32768 --max-batch 1 --max-tokens 4096 \
  --prefix-cache on --no-decode-graphs --default-presence-penalty 1.5 >"$logfile" 2>&1 &
printf '%s\n' "$!" >"$pidfile"
sleep 5
kill -0 "$(<"$pidfile")"
printf 'TP head started: pid=%s log=%s\n' "$(<"$pidfile")" "$logfile"

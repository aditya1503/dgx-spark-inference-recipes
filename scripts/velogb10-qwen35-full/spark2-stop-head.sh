#!/usr/bin/env bash
set -euo pipefail

project="${VELOGB10_PROJECT_DIR:-$HOME/velogb10-qwen35-full-tp2}"
pidfile="$project/run/tp-head.pid"
if [[ ! -f "$pidfile" ]]; then
  echo "No managed TP head pidfile. Nothing stopped."
  exit 0
fi

pid="$(<"$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "Stopped managed TP head pid $pid."
else
  echo "Stale managed TP head pidfile for $pid."
fi
rm -f "$pidfile"

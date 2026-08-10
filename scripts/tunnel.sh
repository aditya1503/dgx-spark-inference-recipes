#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

case "${1:-}" in
  deepseek)
    port="${DEEPSEEK_PORT:-8890}"
    target="$SPARK1_SSH_TARGET"
    control_path="${SPARK1_CONTROL_PATH:-}"
    ;;
  qwen)
    port="${QWEN_PORT:-8892}"
    target="$SPARK2_SSH_TARGET"
    control_path="${SPARK2_CONTROL_PATH:-}"
    ;;
  *)
    echo "Usage: $0 {deepseek|qwen}" >&2
    exit 2
    ;;
esac

opts=(-N -L "${port}:127.0.0.1:${port}" -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3)
[[ -n "$control_path" ]] && opts+=(-S "$control_path")
exec ssh "${opts[@]}" "$target"

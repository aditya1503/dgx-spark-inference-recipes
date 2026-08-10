#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

profile="${1:-}"
allow_concurrent=0
yes=0

for arg in "$@"; do
  case "$arg" in
    --allow-concurrent) allow_concurrent=1 ;;
    --yes) yes=1 ;;
  esac
done

case "$profile" in
  smaller|--allow-concurrent|--yes) profile=smaller ;;
  larger) ;;
  *)
    echo "Usage: $0 {smaller|larger} [--allow-concurrent] [--yes]" >&2
    exit 2
    ;;
esac

if ssh_spark1 "docker ps --format '{{.Names}}'" | grep -Fxq qwen35-9b-vl-mp-tp2-worker || ssh_spark2 "docker ps --format '{{.Names}}'" | grep -Fxq qwen35-9b-vl-mp-tp2-head; then
  if [[ "$allow_concurrent" -ne 1 || "$yes" -ne 1 ]]; then
    echo "Qwen TP=2 is active. Refusing narrow-margin concurrent launch." >&2
    echo "Stop Qwen first, or use --allow-concurrent --yes only for a monitored test." >&2
    exit 3
  fi
fi

if [[ "$yes" -ne 1 ]]; then
  confirm "Launch DeepSeek $profile profile on both Sparks?" || exit 1
fi

ssh_spark1 "bash $DEEPSEEK_PROJECT_DIR/scripts/launch-${profile}_context.sh"
echo "DeepSeek launch requested. Run ./scripts/status.sh until the API is ready."

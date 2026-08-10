#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

read -r -p 'Start Qwen3.5-9B NVFP4 TP=2 on both Sparks? [y/N] ' answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

ssh_spark1 "bash $SPARK1_QWEN_PROJECT_DIR/scripts/spark1-start-worker.sh"
ssh_spark2 "bash $SPARK2_QWEN_PROJECT_DIR/scripts/spark2-start-head.sh"

for attempt in $(seq 1 90); do
  if ssh_spark2 "curl -fsS --max-time 3 -H 'Authorization: Bearer ${LOCAL_API_KEY:-local}' http://127.0.0.1:${QWEN_PORT:-8892}/v1/models >/dev/null"; then
    echo 'Qwen API is ready at Spark 2 loopback port 8892.'
    exit 0
  fi
  printf 'Waiting for API readiness (%d/90)...\n' "$attempt"
  sleep 5
done

echo 'API did not become ready within 7.5 minutes. Run ./logs.sh.' >&2
exit 1

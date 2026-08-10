#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

status() {
  local label="$1"
  local runner="$2"
  echo "===== $label ====="
  "$runner" 'free -h; echo CONTAINERS; docker ps --format "table {{.Names}}\t{{.Status}}"; echo GPU; nvidia-smi --query-compute-apps=process_name,used_gpu_memory --format=csv,noheader,nounits || true; echo SWAP; vmstat 1 2'
}

status "Spark 1" ssh_spark1
status "Spark 2" ssh_spark2

echo "===== PRIVATE APIS ====="
ssh_spark1 "curl --connect-timeout 3 --max-time 15 -sS -H 'Authorization: Bearer ${LOCAL_API_KEY:-local}' -w '\\nDeepSeek HTTP:%{http_code}\\n' http://127.0.0.1:${DEEPSEEK_PORT:-8890}/v1/models || true"
ssh_spark2 "curl --connect-timeout 3 --max-time 15 -sS -H 'Authorization: Bearer ${LOCAL_API_KEY:-local}' -w '\\nQwen HTTP:%{http_code}\\n' http://127.0.0.1:${QWEN_PORT:-8892}/v1/models || true"

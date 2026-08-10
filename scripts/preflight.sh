#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

probe() {
  local label="$1"
  local runner="$2"
  echo "===== $label ====="
  "$runner" 'hostname; free -h; docker --version; nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader; ip -4 addr show; command -v ibv_devinfo >/dev/null && ibv_devinfo -l || true'
}

probe "Spark 1" ssh_spark1
probe "Spark 2" ssh_spark2

echo "===== RoCE SSH ====="
ssh_spark1 "ping -c 2 -W 2 ${SPARK2_ROCE_IP:?SPARK2_ROCE_IP is required}"
ssh_spark2 "ping -c 2 -W 2 ${SPARK1_ROCE_IP:?SPARK1_ROCE_IP is required}"

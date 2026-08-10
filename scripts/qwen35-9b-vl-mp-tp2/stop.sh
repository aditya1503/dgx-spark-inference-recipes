#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

read -r -p 'Stop Qwen TP=2 on both Sparks? [y/N] ' answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

ssh_spark2 "bash $SPARK2_QWEN_PROJECT_DIR/scripts/spark2-stop-head.sh"
ssh_spark1 "bash $SPARK1_QWEN_PROJECT_DIR/scripts/spark1-stop-worker.sh"
echo 'Qwen head and worker are stopped. Containers remain available for restart.'

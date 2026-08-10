#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

require_yes_or_confirm "Stop Qwen TP=2 on both Sparks?" "${1:-}"

ssh_spark2 "bash $SPARK2_QWEN_PROJECT_DIR/scripts/spark2-stop-head.sh"
ssh_spark1 "bash $SPARK1_QWEN_PROJECT_DIR/scripts/spark1-stop-worker.sh"

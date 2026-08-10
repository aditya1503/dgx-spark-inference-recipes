#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

ssh_spark1 "bash $SPARK1_QWEN_PROJECT_DIR/scripts/spark1-status.sh"
ssh_spark2 "bash $SPARK2_QWEN_PROJECT_DIR/scripts/spark2-status.sh"

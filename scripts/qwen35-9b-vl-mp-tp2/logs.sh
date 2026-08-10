#!/usr/bin/env bash
set -euo pipefail

LINES="${1:-200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

ssh_spark1 "bash $SPARK1_QWEN_PROJECT_DIR/scripts/spark1-logs.sh $LINES"
ssh_spark2 "bash $SPARK2_QWEN_PROJECT_DIR/scripts/spark2-logs.sh $LINES"

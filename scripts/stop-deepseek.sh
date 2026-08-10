#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

require_yes_or_confirm "Stop DeepSeek on both Sparks?" "${1:-}"

ssh_spark1 "bash $DEEPSEEK_PROJECT_DIR/scripts/stop.sh"

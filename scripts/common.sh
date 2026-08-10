#!/usr/bin/env bash
set -euo pipefail

RECIPE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${DUAL_SPARK_CONFIG:-$RECIPE_ROOT/config/dual-spark.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing configuration: $CONFIG_FILE" >&2
  echo "Copy config/dual-spark.env.example to config/dual-spark.env and edit it." >&2
  exit 2
fi

source "$CONFIG_FILE"

: "${SPARK1_SSH_TARGET:?SPARK1_SSH_TARGET is required}"
: "${SPARK2_SSH_TARGET:?SPARK2_SSH_TARGET is required}"
: "${DEEPSEEK_PROJECT_DIR:?DEEPSEEK_PROJECT_DIR is required}"
: "${SPARK1_QWEN_PROJECT_DIR:?SPARK1_QWEN_PROJECT_DIR is required}"
: "${SPARK2_QWEN_PROJECT_DIR:?SPARK2_QWEN_PROJECT_DIR is required}"

ssh_spark1() {
  local -a opts=(-o BatchMode=yes -o ConnectTimeout=10)
  [[ -n "${SPARK1_CONTROL_PATH:-}" ]] && opts+=(-S "$SPARK1_CONTROL_PATH")
  ssh "${opts[@]}" "$SPARK1_SSH_TARGET" "$@"
}

ssh_spark2() {
  local -a opts=(-o BatchMode=yes -o ConnectTimeout=10)
  [[ -n "${SPARK2_CONTROL_PATH:-}" ]] && opts+=(-S "$SPARK2_CONTROL_PATH")
  ssh "${opts[@]}" "$SPARK2_SSH_TARGET" "$@"
}

confirm() {
  local prompt="$1"
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

require_yes_or_confirm() {
  local message="$1"
  if [[ "${2:-}" == "--yes" ]]; then
    return 0
  fi
  confirm "$message"
}

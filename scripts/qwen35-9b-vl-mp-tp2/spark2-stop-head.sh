#!/usr/bin/env bash
set -euo pipefail

CONTAINER=qwen35-9b-vl-mp-tp2-head

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "$CONTAINER does not exist."
  exit 0
fi

if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != true ]]; then
  echo "$CONTAINER is already stopped."
  exit 0
fi

docker stop --time 30 "$CONTAINER"

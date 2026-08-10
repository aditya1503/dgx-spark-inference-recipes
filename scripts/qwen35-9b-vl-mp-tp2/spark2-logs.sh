#!/usr/bin/env bash
set -euo pipefail

docker logs --tail "${1:-200}" qwen35-9b-vl-mp-tp2-head

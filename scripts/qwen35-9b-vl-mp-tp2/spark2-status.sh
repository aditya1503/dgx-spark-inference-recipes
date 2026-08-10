#!/usr/bin/env bash
set -euo pipefail

CONTAINER=qwen35-9b-vl-mp-tp2-head

docker ps -a --filter "name=^/${CONTAINER}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' "$CONTAINER" 2>/dev/null || true
free -h
ss -lntp | grep -E ':(29501|8892)' || true
curl -fsS --max-time 3 -H 'Authorization: Bearer local' http://127.0.0.1:8892/v1/models || true
echo

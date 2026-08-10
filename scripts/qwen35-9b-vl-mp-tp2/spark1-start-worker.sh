#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${QWEN_PROJECT_DIR:-$HOME/qwen35-9b-vl-mp-tp2}"
CACHE_DIR="${QWEN_CACHE_DIR:-$PROJECT_DIR/model-cache}"
CONTAINER=qwen35-9b-vl-mp-tp2-worker
IMAGE='nvcr.io/nvidia/vllm@sha256:95c498a475142c20c989c65e5d223348c09fed83ba17ddf44f117610c0bd3268'
MODEL='AxionML/Qwen3.5-9B-NVFP4'
REVISION='97aef92393f126bf649f310cd40861be8dad3279'

ibv_devinfo -d rocep1s0f1 | grep -q 'active_mtu:[[:space:]]*4096' || {
  echo 'rocep1s0f1 active MTU is not 4096; refusing to launch.' >&2
  exit 1
}

test -f "$CACHE_DIR/models--AxionML--Qwen3.5-9B-NVFP4/snapshots/$REVISION/model.safetensors"

if docker inspect "$CONTAINER" >/dev/null 2>&1; then
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" == true ]]; then
    echo "$CONTAINER is already running."
    exit 0
  fi
  docker start "$CONTAINER"
  exit 0
fi

docker run -d \
  --name "$CONTAINER" \
  --restart=no \
  --gpus all \
  --device=/dev/infiniband:/dev/infiniband:rwm \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  --network=host \
  --ipc=host \
  -v "$CACHE_DIR:/cache:ro" \
  -e HF_HOME=/cache \
  -e HF_HUB_CACHE=/cache \
  -e HF_HUB_OFFLINE=1 \
  -e VLLM_HOST_IP=10.200.1.1 \
  -e NCCL_NET=IB \
  -e NCCL_IB_DISABLE=0 \
  -e NCCL_IB_HCA=rocep1s0f1 \
  -e NCCL_IB_GID_INDEX=3 \
  -e NCCL_CROSS_NIC=1 \
  -e NCCL_CUMEM_ENABLE=0 \
  -e NCCL_IGNORE_CPU_AFFINITY=1 \
  -e NCCL_NVLS_ENABLE=0 \
  -e NCCL_SOCKET_IFNAME=enp1s0f1np1 \
  -e GLOO_SOCKET_IFNAME=enp1s0f1np1 \
  -e NCCL_DEBUG=INFO \
  -e NCCL_DEBUG_SUBSYS=INIT,NET \
  "$IMAGE" \
  vllm serve "$MODEL" \
  --revision "$REVISION" \
  --served-model-name qwen35-9b-nvfp4-dual-spark \
  --tensor-parallel-size 2 \
  --distributed-executor-backend mp \
  --nnodes 2 \
  --node-rank 1 \
  --master-addr 10.200.1.2 \
  --master-port 29501 \
  --headless \
  --quantization modelopt_fp4 \
  --dtype bfloat16 \
  --trust-remote-code \
  --disable-custom-all-reduce \
  --max-model-len 8192 \
  --max-num-seqs 1 \
  --max-num-batched-tokens 8192 \
  --gpu-memory-utilization 0.10 \
  --kv-cache-memory-bytes 536870912 \
  --mm-processor-cache-gb 0.25 \
  --mm-encoder-tp-mode weights \
  --limit-mm-per-prompt '{"image":1,"video":0}' \
  --reasoning-parser qwen3 \
  --compilation-config '{"mode":0,"cudagraph_mode":"FULL_DECODE_ONLY","cudagraph_capture_sizes":[1]}'

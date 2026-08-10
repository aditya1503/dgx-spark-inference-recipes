# Qwen3.5-9B NVFP4 vision TP=2 on two DGX Sparks

## Locked deployment

- Model: `AxionML/Qwen3.5-9B-NVFP4`
- Revision: `97aef92393f126bf649f310cd40861be8dad3279`
- Weight SHA256: `a1304acf8325cee90075bf8eb7f5e973ef893c7d497ded92e7d720f0e7178749`
- Image: `nvcr.io/nvidia/vllm@sha256:95c498a475142c20c989c65e5d223348c09fed83ba17ddf44f117610c0bd3268`
- API model: `qwen35-9b-nvfp4-dual-spark`
- vLLM: `0.24.0+092c4842.dev`
- PyTorch: `2.13.0a0+9186a08b2c.nv26.07`

## Topology

```text
Spark 2: rank 0, API 127.0.0.1:8892
    |
    | NCCL/IB over rocep1s0f1, GID 3
    |
Spark 1: headless rank 1
```

- Tensor parallel size: 2
- Executor: native vLLM multiprocessing, no Ray
- Rendezvous: Spark 2 `10.200.1.2:29501`
- Socket/Gloo interface: `enp1s0f1np1`
- Quantization: `modelopt_fp4`
- Context: 8,192 tokens
- Maximum sequences: 1
- Fixed KV cache: 512 MiB per rank
- Validated KV capacity: 26,731 tokens, 3.26x concurrency at 8,192 tokens
- Multimodal processor cache: 0.25 GiB; 0.125 GiB is too small for the maximum dummy image item and fails with `cachetools ValueError: value too large`
- GPU memory utilization: 0.10 admission guard; fixed KV sizing controls the actual KV reservation
- CUDA graphs: `FULL_DECODE_ONLY`
- Docker restart policy: `no`

## Operations

The complete operations folder is `scripts/qwen35-9b-vl-mp-tp2/`.

```bash
cd scripts/qwen35-9b-vl-mp-tp2
./start.sh
./status.sh
./logs.sh
./stop.sh
```

Start order is Spark 1 worker then Spark 2 head. Stop order is Spark 2 head then Spark 1 worker. The start script waits for `/v1/models` readiness.

## Private tunnel

```bash
./scripts/qwen35-9b-vl-mp-tp2/tunnel.sh
```

This forwards workstation `127.0.0.1:8892` directly to Spark 2 loopback. The older Spark-1-to-RoCE-port tunnel does not work because the API intentionally binds only to Spark 2 loopback.

## OpenAI-compatible request

Use both the served model name and local bearer key:

```text
URL: http://127.0.0.1:8892/v1/chat/completions
Model: qwen35-9b-nvfp4-dual-spark
Authorization: Bearer local
```

For normal text in `message.content`, include:

```json
{"chat_template_kwargs":{"enable_thinking":false}}
```

## Validated result

- Real PNG image-to-text request passed
- API listener confirmed at `127.0.0.1:8892`
- NCCL logs confirmed `NET/IB`, `rocep1s0f1`, GID 3, two ranks, and `Init COMPLETE`
- Idle container memory measured at approximately 6.05 GiB on Spark 1 and 8.64 GiB on Spark 2
- Host memory available after startup was approximately 105 GiB on Spark 1 and 102 GiB on Spark 2
- Stopped `*-pre-512m` containers retain the previous 1 GiB KV configuration for rollback and consume no runtime RAM

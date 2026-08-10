# Qwen3.5-9B NVFP4 vision on two DGX Sparks

This folder controls the validated native-vLLM `mp` TP=2 deployment. Spark 2 is rank 0 and hosts the private API. Spark 1 is the headless rank-1 worker. Nothing is configured to start at boot.

## Locked deployment

- Model: `AxionML/Qwen3.5-9B-NVFP4`
- Revision: `97aef92393f126bf649f310cd40861be8dad3279`
- Weight SHA256: `a1304acf8325cee90075bf8eb7f5e973ef893c7d497ded92e7d720f0e7178749`
- Container: `nvcr.io/nvidia/vllm@sha256:95c498a475142c20c989c65e5d223348c09fed83ba17ddf44f117610c0bd3268`
- Runtime: vLLM `0.24.0+092c4842.dev`, PyTorch `2.13.0a0+9186a08b2c.nv26.07`
- Executor: native multiprocessing, no Ray
- Tensor parallelism: 2 nodes, 1 GPU per node
- Context: 8,192 tokens; one sequence
- KV cache: fixed 512 MiB per rank
- Multimodal processor cache: 0.25 GiB per node
- GPU admission setting: `0.10`
- API: Spark 2 loopback only, `127.0.0.1:8892`
- Served model: `qwen35-9b-nvfp4-dual-spark`

The fixed KV cache overrides dynamic KV sizing. The 0.10 value is therefore an admission guard, not a request for vLLM to reserve 10% for KV cache. The validated 512 MiB profile provides 26,731 KV tokens and 3.26x maximum concurrency at the configured 8,192-token request limit.

## Start

First establish the SSH masters:

```bash
~/ssh_mnf.sh
```

Then, from this directory:

```bash
./start.sh
```

The worker starts first, followed by the head. Startup normally takes roughly 3.5 to 5 minutes. The script waits until `/v1/models` is ready.

## Stop

```bash
./stop.sh
```

The head stops first, followed by the worker. The containers and model caches remain on disk for a fast restart.

## Status and logs

```bash
./status.sh
./logs.sh
./logs.sh 500
```

## Private tunnel

Run this in a separate Mac terminal:

```bash
./tunnel.sh
```

It forwards Mac `127.0.0.1:8892` directly to Spark 2 `127.0.0.1:8892`. Do not use the older Spark-1-to-`10.200.1.2:8892` tunnel because the API deliberately listens only on Spark 2 loopback.

## Test and benchmark

With the tunnel active:

```bash
curl -H 'Authorization: Bearer local' http://127.0.0.1:8892/v1/models
./vision_test.sh /absolute/path/to/image.png
python3 vision_test.py /absolute/path/to/image.jpeg
./benchmark.sh
```

Qwen3.5 may put chain-of-thought tokens in `message.reasoning` before `message.content`. The vision test prints both fields. The text benchmark disables thinking to measure answer-generation speed rather than reasoning length.

## OpenCode provider

```json
"spark_vision": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Dual DGX Spark — Qwen3.5 Vision",
  "options": {
    "baseURL": "http://127.0.0.1:8892/v1",
    "apiKey": "local",
    "timeout": 600000,
    "chunkTimeout": 120000
  },
  "models": {
    "qwen35-9b-nvfp4-dual-spark": {
      "name": "Qwen3.5 9B NVFP4 Vision (Dual Spark)",
      "limit": { "context": 8192, "output": 4096 }
    }
  }
}
```

## Security and networking

- The API binds only to Spark 2 loopback.
- Distributed rendezvous uses `10.200.1.2:29501`.
- Spark 2 permits port 29501 only from its own loopback address and Spark 1 at `10.200.1.1` on `enp1s0f1np1`.
- NCCL is pinned to `rocep1s0f1`, GID index 3, with sockets/Gloo on `enp1s0f1np1`.
- Firewall rules are runtime-only and must be recreated after a reboot before starting this deployment.
- Both containers use Docker restart policy `no`.

## Validated result

- `/v1/models`: passed
- Text completion: passed
- Real PNG image-to-text request: passed
- RoCE: logs show `NCCL INFO NET/IB`, `devName=rocep1s0f1`, `GID 3`, `Connected all rings`, and two-rank `Init COMPLETE`
- Container memory at idle after the 512 MiB KV reduction: approximately 6.05 GiB on Spark 1 and 8.64 GiB on Spark 2

See [ROLLBACK.md](./ROLLBACK.md) for reversible cleanup instructions.

# Dual DGX Spark inference recipes

Reproducible, private-by-default recipes for serving large language and vision models across two NVIDIA DGX Spark systems connected by RoCE. The repository contains the exact model/image pins, native tensor-parallel launch scripts, lifecycle wrappers, memory guidance, validation tools, and rollback notes used on a working two-node GB10 cluster.

The primary validated deployment is Qwen3.5-9B NVFP4 vision with native vLLM multiprocessing. DeepSeek V4 Flash profiles and an archived veloGB10 text experiment are also documented.

## Validated services

| Service | Runtime | TP | API node | Private API | Status |
| --- | --- | ---: | --- | --- | --- |
| Qwen3.5-9B NVFP4 vision | vLLM native `mp` | 2 | Spark 2 | `127.0.0.1:8892` | Image-to-text validated |
| DeepSeek V4 Flash | vLLM native `mp` | 2 | Spark 1 | `127.0.0.1:8890` | Separate documented profiles |
| Qwen3.5-9B NVFP4-FULL | veloGB10 | 2 | Spark 2 | `127.0.0.1:8892` | Archived text-only experiment |

No service is configured to start at boot. Docker containers use restart policy `no`, and no script binds an API publicly.

## Qwen vision deployment

### Locked artifacts

- Model: `AxionML/Qwen3.5-9B-NVFP4`
- Revision: `97aef92393f126bf649f310cd40861be8dad3279`
- Weight SHA256: `a1304acf8325cee90075bf8eb7f5e973ef893c7d497ded92e7d720f0e7178749`
- Container: `nvcr.io/nvidia/vllm@sha256:95c498a475142c20c989c65e5d223348c09fed83ba17ddf44f117610c0bd3268`
- Served model: `qwen35-9b-nvfp4-dual-spark`
- Context: 8,192 tokens
- Maximum sequences: 1
- KV cache: fixed 512 MiB per rank
- Multimodal processor cache: 0.25 GiB per node
- CUDA graphs: `FULL_DECODE_ONLY`

The 512 MiB KV profile provides 26,731 KV tokens and 3.26x theoretical concurrency at the configured 8,192-token request limit. Do not reduce the multimodal processor cache to 0.125 GiB: the maximum image preprocessing item does not fit and startup fails with `cachetools ValueError: value too large`.

### Topology

```text
Spark 2: rank 0, API 127.0.0.1:8892
    |
    | torch.distributed 10.200.1.2:29501
    | NCCL/IB, rocep1s0f1, GID 3
    |
Spark 1: headless rank 1
```

NCCL and Gloo are pinned to the RoCE path. Wi-Fi may remain the host default route but is not used for tensor-parallel traffic.

### Observed result

- Spark 1 container memory: approximately 6.05 GiB
- Spark 2 container memory: approximately 8.64 GiB
- Host memory available after startup: approximately 105 GiB and 102 GiB
- `/v1/models`: passed
- Text completion: passed
- Real PNG image-to-text request: passed
- NCCL logs: `NET/IB`, `rocep1s0f1`, GID 3, two ranks, `Init COMPLETE`

DGX Spark uses unified memory. GPU and host-memory columns can overlap and must not be added together. Repeated `VLLM::Worker_TP` rows in `htop` may be threads sharing one address space rather than independent model copies.

## Safety boundaries

These recipes intentionally do not:

- modify or delete Conda environments;
- run `apt upgrade` or `apt autoremove`;
- install or replace NVIDIA drivers;
- expose model APIs on `0.0.0.0`;
- create systemd or boot-time services;
- delete model caches or shared images during normal stop operations.

Before running destructive or host-level cleanup commands, inspect the exact targets and obtain explicit approval.

## Repository layout

```text
config/
  dual-spark.env.example       Public configuration template
docs/
  deepseek-v4-flash.md         DeepSeek profiles and pins
  qwen35-nvfp4.md              Validated Qwen vision recipe
  memory.md                    GB10 unified-memory accounting
  security.md                  Private API and RoCE rules
scripts/
  preflight.sh                 Read-only cluster checks
  status.sh                    Both-node status and private API checks
  start-deepseek.sh            Guarded DeepSeek launcher
  stop-deepseek.sh             Guarded DeepSeek stop
  start-qwen-tp2.sh            Guarded native-mp Qwen launcher
  stop-qwen-tp2.sh             Guarded Qwen stop
  tunnel.sh                    Private SSH forwarding
  qwen35-9b-vl-mp-tp2/        Complete Qwen operations package
  velogb10-qwen35-full/        Archived non-vision experiment
```

Runtime configuration, logs, PID files, model caches, tokens, and secrets are ignored by Git.

## Prerequisites

- Two DGX Sparks with working Docker GPU passthrough
- RoCE links configured and persistent
- `ibv_devinfo` reporting `PORT_ACTIVE` and `active_mtu: 4096`
- Passwordless or multiplexed SSH access from the control workstation
- The pinned container image and model snapshot already present on both nodes
- Port 29501 allowed only between the two private RoCE peers for Qwen rendezvous
- `curl`, `jq`, and Bash on the control workstation
- `autossh` only if persistent tunnels are desired

## Configure

```bash
cp config/dual-spark.env.example config/dual-spark.env
chmod 600 config/dual-spark.env
$EDITOR config/dual-spark.env
```

`config/dual-spark.env` is ignored by Git. Set the SSH targets, ControlPath values, private RoCE addresses, per-node project directories, ports, and local API key there.

Run the read-only checks:

```bash
./scripts/preflight.sh
./scripts/status.sh
```

## Start, stop, and inspect Qwen

The dedicated operations folder starts Spark 1 first and Spark 2 second, then waits for API readiness:

```bash
cd scripts/qwen35-9b-vl-mp-tp2
./start.sh
./status.sh
./logs.sh
./logs.sh 500
./stop.sh
```

Normal stop preserves containers and model caches for restart. See [Qwen rollback instructions](scripts/qwen35-9b-vl-mp-tp2/ROLLBACK.md) before removing anything.

## Private tunnels

From the repository root:

```bash
./scripts/tunnel.sh qwen
./scripts/tunnel.sh deepseek
```

The Qwen tunnel maps workstation `127.0.0.1:8892` directly to Spark 2 loopback. Do not forward through Spark 1 to Spark 2's RoCE address because the API deliberately does not listen there.

## Validate vision and performance

With the Qwen tunnel active:

```bash
curl -H 'Authorization: Bearer local' \
  http://127.0.0.1:8892/v1/models

python3 scripts/qwen35-9b-vl-mp-tp2/vision_test.py \
  /absolute/path/to/image.jpeg

scripts/qwen35-9b-vl-mp-tp2/benchmark.sh
```

For a normal answer in `message.content`, include:

```json
{"chat_template_kwargs":{"enable_thinking":false}}
```

Qwen may otherwise emit reasoning in `message.reasoning` or `message.reasoning_content` before returning `message.content`.

## OpenCode provider

```json
"spark-qwen": {
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
      "name": "Qwen3.5 9B NVFP4 Vision",
      "modalities": {"input": ["text", "image"]},
      "limit": {"context": 8192, "output": 4096}
    }
  }
}
```

An OpenCode vision router should call Qwen with `Authorization: Bearer local`, set `enable_thinking` to false for concise image analysis, remove image objects before forwarding the analysis to a text-only model, and return an error rather than forwarding unsupported image payloads when vision preprocessing fails.

## Troubleshooting

- API not listening: inspect both containers; Spark 1 may be waiting correctly for rank 0.
- Architecture inspection `SIGSEGV`: verify `OOMKilled=false`; a fresh head retry may recover a transient vLLM subprocess crash.
- `value too large` during dummy image profiling: restore `--mm-processor-cache-gb 0.25`.
- NCCL uses sockets/Wi-Fi: verify `NCCL_NET=IB`, `NCCL_IB_HCA`, GID index, and socket-interface settings.
- Qwen returns `content: null`: inspect `reasoning` and `reasoning_content`, increase `max_tokens`, or disable thinking.
- High yellow memory in `htop`: inspect `MemAvailable` and container cgroups; yellow is generally reclaimable file cache.

## Initialize and push a repository

This directory can be published after reviewing `git status` and confirming that `config/dual-spark.env` remains ignored.

```bash
git init -b main
git add .
git status
git commit -m "Add validated dual DGX Spark inference recipes"
git remote add origin git@github.com:YOUR_GITHUB_USER/dgx-spark-inference-recipes.git
git push -u origin main
```

Using GitHub CLI instead:

```bash
gh repo create dgx-spark-inference-recipes --private --source=. --remote=origin --push
```

Use `--public` only after independently reviewing the staged files for hostnames, usernames, tokens, private configuration, logs, and model artifacts.

## Further documentation

- [Qwen3.5 NVFP4 vision](docs/qwen35-nvfp4.md)
- [DeepSeek V4 Flash](docs/deepseek-v4-flash.md)
- [Unified-memory accounting](docs/memory.md)
- [Networking and security](docs/security.md)

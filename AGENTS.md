# AGENTS.md

## What this repo is

Control-plane Bash recipes for serving LLMs across two NVIDIA DGX Sparks connected by RoCE. There is **no app code, no build, no lint, no test framework**. Verification is remote: run the read-only scripts and curl the private APIs. Do not invent unit-test or typecheck commands.

## The big gotcha: everything runs over SSH from this workstation

`scripts/*.sh` are wrappers that source `scripts/common.sh` and run commands on the two Sparks through `ssh_spark1`/`ssh_spark2`. Nothing meaningful executes locally. Some repo wrappers (e.g. `start-deepseek.sh`) call a **separate, unpinned remote project** located at `DEEPSEEK_PROJECT_DIR`; the Qwen ops package calls remote `scripts/sparkN-*.sh` located at `SPARK{1,2}_QWEN_PROJECT_DIR`. Remote paths, ports, RoCE IPs, and SSH targets all come from `config/dual-spark.env`.

## Required config

- Copy `config/dual-spark.env.example` to `config/dual-spark.env` and edit it; `common.sh` exits 2 if it is missing.
- `config/dual-spark.env` is git-ignored and may contain secrets/keys. Never commit it or print its contents.
- Optional: override the path with `DUAL_SPARK_CONFIG` or edit the actual file directly.

## Deployment map (ports from status.sh: qwen port 8892, deepseek 8890)

| Service | TP | API node | Private port | Launch |
| --- | ---: | --- | ---: | --- |
| Qwen3.5-9B NVFP4 vision (validated) | 2 | Spark 2 | 127.0.0.1:8892 | `scripts/qwen35-9b-vl-mp-tp2/` |
| DeepSeek V4 Flash | 2 | Spark 1 | 127.0.0.1:8890 | `./scripts/start-deepseek.sh {smaller\|larger}` |
| veloGB10 Qwen NVFP4-FULL | 2 | Spark 2 | 127.0.0.1:8892 | `scripts/velogb10-qwen35-full/` — archived, text-only |

Qwen API binds **only to Spark 2 loopback**. Use `./scripts/tunnel.sh qwen` (direct workstation → Spark 2). Never tunnel via Spark 1 → Spark 2's RoCE address; the API does not listen there.

## Order invariants (do not reorder)

- Qwen start: **Spark 1 worker first, then Spark 2 head**; `start.sh` waits for `/v1/models`.
- Qwen stop: **Spark 2 head first, then Spark 1 worker**. `stop.sh` stops containers but keeps them (and caches) for fast restart.
- DeepSeek: `start-deepseek.sh` refuses to launch while Qwen containers are running unless passed `--allow-concurrent --yes` (monitored test only). Don't bypass casually.

## Smoke-test commands

```bash
./scripts/preflight.sh                 # read-only cluster/RoCE checks
./scripts/status.sh                    # both nodes + private API /v1/models checks
cd scripts/qwen35-9b-vl-mp-tp2 && ./start.sh && ./status.sh && ./logs.sh [N] && ./stop.sh
./scripts/tunnel.sh qwen               # foreground; run in separate terminal
curl -H 'Authorization: Bearer local' http://127.0.0.1:8892/v1/models
python3 scripts/qwen35-9b-vl-mp-tp2/vision_test.py /absolute/path/to/image.jpeg
```

## Repo-specific gotchas

- **Unified memory (GB10):** GPU (`nvidia-smi`/`nvtop`) and host (`free -h`) views are the same physical LPDDR5X pool; never add them. Use `free -h`, container memory, `vmstat 1`. Yellow `htop` memory is usually reclaimable file cache.
- **Qwen flags are locked:** `--mm-processor-cache-gb 0.25` (0.125 fails at startup with `cachetools ValueError: value too large`); fixed `--kv-cache-memory-bytes 536870912` (512 MiB); `--gpu-memory-utilization 0.10` is an admission guard, not a KV reservation; `--quantization modelopt_fp4`; CUDA graphs `FULL_DECODE_ONLY`.
- **Qwen reasoning:** set `{"chat_template_kwargs":{"enable_thinking":false}}` or answers land in `message.reasoning`/`reasoning_content` instead of `content`.
- Skip the `~/ssh_mnf.sh` step in package READMEs if SSH ControlPath sockets are already up; `-S` just uses them when set.
- Everything is pinned (model revision, image digest, weights); treat pins as a unit and never float to tags/branches.
- No boot-time services; containers use restart policy `no`. Firewall rules for port 29501 are runtime-only and must be recreated after reboot.

## Never do without explicit approval

- Host-level cleanup: `apt upgrade`/`autoremove`, driver installs, conda env modification, deleting model caches/shared images.
- Destructive rollback (containers, caches, project dirs, iptables rules). See `scripts/qwen35-9b-vl-mp-tp2/ROLLBACK.md`; stopped `*-pre-512m` containers and the shared NVIDIA image are rollback assets — inspect targets before removing.
- Exposing APIs on `0.0.0.0` or adding reverse proxies.

## Docs

`docs/` is authoritative for pins and details: `security.md` (networking/RoCE rules), `memory.md` (unified-memory accounting), `qwen35-nvfp4.md`, `deepseek-v4-flash.md`. If README/docs conflict with a script, trust the script.

# DeepSeek V4 Flash on two DGX Sparks

## Deployed reference

The deployed reference is the official `deepseek-ai/DeepSeek-V4-Flash-0731` FP8 release using a locked DSpark recipe. The deployed project records the recipe commit `d728faee9f5a8d5ebafe7bc44bca6c5d8d0d192f`, official model revision `7872f01b1d1fe23eabc4c98b48bffcef5a386062`, and runtime base digest `ghcr.io/bjk110/vllm-spark@sha256:d8492e7677cf1b9aaa3344e0e6865efc468454013eee5ebabac85be90af027be`.

Treat all three as a unit. Do not replace them with a floating branch or tag without a separate validation pass.

## Topology

```text
Spark 1 (head/API, 127.0.0.1:8890)  <── RoCE / NCCL IB ──>  Spark 2 (worker)
```

- Tensor parallelism: 2.
- Distributed executor: `mp`, not Ray.
- RoCE socket interface: `enp1s0f1np1`.
- RoCE HCA: `rocep1s0f1`.
- API is private: loopback binding on Spark 1 only.

## Profiles

| Profile | `MAX_MODEL_LEN` | `MAX_NUM_SEQS` | GPU memory utilization |
| --- | ---: | ---: | ---: |
| `smaller_context` | 200,000 | 2 | 0.75 |
| `larger_context` | 1,048,576 | 12 | 0.75 |

Use the wrappers rather than editing the active environment manually:

```bash
./scripts/start-deepseek.sh smaller
./scripts/start-deepseek.sh larger
```

## Expected allocation

Observed steady allocation is about 95 GiB on Spark 1 and 91 GiB on Spark 2. This includes approximately 88 GiB of model weights plus runtime allocation. On GB10, that allocation consumes the same unified LPDDR5X pool reported by `free -h`.

## Validation

```bash
curl http://127.0.0.1:8890/v1/models
```

Use the project smoke and benchmark tools after readiness. Check logs for `Using network IB` and `NET/IB` to confirm RoCE rather than Wi-Fi.

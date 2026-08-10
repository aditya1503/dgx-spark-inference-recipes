# GB10 unified-memory accounting

DGX Spark GB10 systems use a shared unified LPDDR5X memory pool. GPU memory in `nvtop`/`nvidia-smi` and host memory in `free -h` are not separate physical memory pools.

## Reading the tools

- `GPU MEM` is the GPU allocator's view of the model/runtime allocation.
- `free -h` includes the same underlying physical memory pool plus operating-system and CPU-process allocations.
- `VIRT` in `htop` is address space, not resident memory. Use `RES`, container memory, `free -h`, and `vmstat` instead.
- A nonzero swap total is not automatically active thrashing. Use `vmstat 1`; sustained nonzero `si` or `so` indicates active swap pressure.

## Observed deployments

| Deployment | GPU allocation per node | CPU-side runtime |
| --- | ---: | --- |
| Qwen TP=2 | about 6.05 GiB Spark 1 and 8.64 GiB Spark 2 container memory | Native-mp worker on both; API and EngineCore on Spark 2 |
| DeepSeek TP=2 | about 95 GiB Spark 1, 91–97 GiB Spark 2 | about 2–3 GiB worker process |

## Concurrent operation

DeepSeek plus Qwen co-loading was observed at roughly 112–113 GiB used out of 121 GiB on each Spark, with 4–9 GiB swap resident. It can remain idle without active swapping, but leaves little headroom for prompt processing, CUDA/runtime transients, or simultaneous requests.

Use concurrent operation only as a monitored experiment. For predictable latency and safety, stop one model before launching the other.

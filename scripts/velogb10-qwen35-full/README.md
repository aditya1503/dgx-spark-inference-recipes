# Qwen3.5-9B NVFP4-FULL with veloGB10 TP=2

This is an archived text-generation experiment using the native veloGB10 engine. It is separate from the validated vLLM vision deployment in `../qwen35-9b-vl-mp-tp2/`.

- Spark 1 runs the TP node on port 29500.
- Spark 2 runs the OpenAI-compatible head on loopback port 8892.
- Model revision: `4a93643d4409820db9c3787120adf5ad1bed781e`
- Model SHA256: `c47ea62ea7c79c696947fe89c734d28dc2efb3158ffb2aff1dada1f707114d65`
- veloGB10 v0.3.1 requires Ethernet MTU 9000 so RDMA reports `active_mtu: 4096`.

Place the project under `$HOME/velogb10-qwen35-full-tp2` on each node or set `VELOGB10_PROJECT_DIR`. Start Spark 1 before Spark 2:

```bash
bash "$HOME/velogb10-qwen35-full-tp2/scripts/spark1-start-node.sh"
bash "$HOME/velogb10-qwen35-full-tp2/scripts/spark2-start-head.sh"
```

Set `VELOGB10_PEER_IP` on Spark 2 if Spark 1 is not `10.200.1.1`. Access port 8892 only through a private SSH tunnel.

The engine has text/tool support, but vision request support was not validated. Use the vLLM recipe for image-to-text workloads.

`--no-decode-graphs` remains enabled because veloGB10 v0.3.1 asserted during TP decode-graph capture. Prefix caching is enabled but has a known TP reuse issue; disable it if requests are unstable.

# Networking and security

## API exposure

Both services bind their OpenAI-compatible APIs only to `127.0.0.1`:

- DeepSeek: Spark 1, port 8890.
- Qwen: Spark 2, port 8892.

Access them with SSH tunnels. Do not publish Docker ports, bind to `0.0.0.0`, or add reverse proxies without an explicit access-control design.

## RoCE

Use dedicated point-to-point RoCE addresses and keep Wi-Fi as the host default route. NCCL should log all of the following:

```text
NCCL_SOCKET_IFNAME=enp1s0f1np1
NET/IB
Using network IB
```

Qwen uses native vLLM multiprocessing rather than Ray. Keep its torch-distributed rendezvous at Spark 2 `10.200.1.2:29501` private: allow Spark 2 loopback and Spark 1 `10.200.1.1` on `enp1s0f1np1`, then reject all other sources for that port.

## Docker lifecycle

Both deployments use `--restart=no`. No systemd unit or boot-time auto-start should be installed. Check this after upgrades or recreating containers:

```bash
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' CONTAINER_NAME
```

## Secrets

Never commit Hugging Face tokens, deployment keys, SSH configurations, private DNS names, or Cloudflare access commands. Keep them in a local ignored configuration file or a secret manager.

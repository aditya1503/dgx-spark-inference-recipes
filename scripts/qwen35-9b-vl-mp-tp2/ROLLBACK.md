# Rollback

The normal rollback is non-destructive: stop the head and worker while preserving the containers, model caches, and scripts.

```bash
./stop.sh
```

Confirm that both are stopped:

```bash
./status.sh
```

The last proven 1 GiB KV containers are retained in a stopped state as:

- Spark 1: `qwen35-9b-vl-mp-tp2-worker-pre-512m`
- Spark 2: `qwen35-9b-vl-mp-tp2-head-pre-512m`

They consume no runtime RAM. Restoring them requires stopping and renaming the current containers, renaming these backups to the production names, and starting worker-first/head-second. Treat that as a system-level rollback and obtain explicit approval before executing it.

Removing containers, model caches, project directories, or firewall rules is destructive or system-level work. Review each command and approve it explicitly before running it.

Optional container removal after stopping:

```bash
source ../../config/dual-spark.env
ssh -S "$SPARK2_CONTROL_PATH" "$SPARK2_SSH_TARGET" \
  'docker rm qwen35-9b-vl-mp-tp2-head'
ssh -S "$SPARK1_CONTROL_PATH" "$SPARK1_SSH_TARGET" \
  'docker rm qwen35-9b-vl-mp-tp2-worker'
```

Optional Spark 2 runtime firewall rollback:

```bash
sudo iptables -D INPUT -p tcp --dport 29501 -j QWEN35_VL_MP_PRIVATE
sudo iptables -F QWEN35_VL_MP_PRIVATE
sudo iptables -X QWEN35_VL_MP_PRIVATE
```

Do not delete the shared NVIDIA image unless every deployment that uses its digest has been identified first. DeepSeek files, containers, scripts, images, and caches are outside this rollback and must not be changed.

#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import time
import urllib.request

url = "http://127.0.0.1:8892/v1/chat/completions"
model = "qwen35-9b-nvfp4-dual-spark"
runs = 3
prompt = "Write a Python merge_sorted_lists function with type hints, validation, a docstring, five tests, and complexity analysis."

print(f"Model: {model}")
print(f"Runs:  {runs}")
print(f"URL:   {url}\n")

for run in range(1, runs + 1):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "seed": 42,
        "max_tokens": 512,
        "stream": True,
        "stream_options": {"include_usage": True},
        "chat_template_kwargs": {"enable_thinking": False},
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer local"},
    )
    started = time.perf_counter()
    first_token_at = None
    usage = {}
    chunks = []

    with urllib.request.urlopen(request, timeout=600) as response:
        for raw in response:
            line = raw.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            event = json.loads(line[6:])
            usage = event.get("usage") or usage
            for choice in event.get("choices", []):
                delta = choice.get("delta", {})
                text = delta.get("content") or delta.get("reasoning") or delta.get("reasoning_content") or ""
                if text:
                    if first_token_at is None:
                        first_token_at = time.perf_counter()
                    chunks.append(text)

    ended = time.perf_counter()
    output_tokens = int(usage.get("completion_tokens", 0))
    input_tokens = int(usage.get("prompt_tokens", 0))
    ttft = (first_token_at - started) if first_token_at else 0.0
    generation_time = max(ended - (first_token_at or started), 0.000001)
    generation_speed = output_tokens / generation_time
    e2e_speed = output_tokens / max(ended - started, 0.000001)

    print(f"========== Run {run} ==========")
    print(f"Input tokens:       {input_tokens}")
    print(f"Output tokens:      {output_tokens}")
    print(f"TTFT:               {ttft:.3f} sec")
    print(f"Generation speed:   {generation_speed:.3f} tok/s")
    print(f"E2E output speed:   {e2e_speed:.3f} tok/s")
    print(f"Completion time:    {ended - started:.3f} sec")
    print(f"Returned text:      {'yes' if ''.join(chunks).strip() else 'no'}\n")
PY

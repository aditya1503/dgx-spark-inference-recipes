#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /absolute/path/to/image.png" >&2
  exit 2
fi

python3 - "$1" <<'PY'
import base64
import json
import mimetypes
import sys
import time
import urllib.request

image_path = sys.argv[1]
url = "http://127.0.0.1:8892/v1/chat/completions"
model = "qwen35-9b-nvfp4-dual-spark"

with open(image_path, "rb") as image_file:
    encoded = base64.b64encode(image_file.read()).decode()
mime_type = mimetypes.guess_type(image_path)[0] or "image/jpeg"

payload = {
    "model": model,
    "messages": [{
        "role": "user",
        "content": [
            {"type": "text", "text": "Describe this image in detail."},
            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64," + encoded}},
        ],
    }],
    "chat_template_kwargs": {"enable_thinking": False},
    "max_tokens": 768,
    "temperature": 0.2,
}

request = urllib.request.Request(
    url,
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json", "Authorization": "Bearer local"},
)
started = time.perf_counter()
with urllib.request.urlopen(request, timeout=600) as response:
    result = json.loads(response.read())
elapsed = time.perf_counter() - started
message = result["choices"][0]["message"]

print(f"Response time: {elapsed:.2f} sec")
if message.get("reasoning") or message.get("reasoning_content"):
    print("\nReasoning:")
    print(message.get("reasoning") or message.get("reasoning_content"))
print("\nAnswer:")
print(message.get("content") or "")
print("\nUsage:")
print(json.dumps(result.get("usage", {}), indent=2))
PY

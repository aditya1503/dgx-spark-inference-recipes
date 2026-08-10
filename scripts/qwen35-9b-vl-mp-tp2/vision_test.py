import base64
import mimetypes
import sys
import time
from pathlib import Path

import requests

image_path = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path("~/Downloads/vindsol.jpeg").expanduser()
api_url = "http://127.0.0.1:8892/v1/chat/completions"
model_name = "qwen35-9b-nvfp4-dual-spark"
mime_type = mimetypes.guess_type(image_path)[0] or "image/jpeg"

with image_path.open("rb") as image_file:
    base64_image = base64.b64encode(image_file.read()).decode("utf-8")

payload = {
    "model": model_name,
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Describe this image in detail."},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:{mime_type};base64,{base64_image}"},
                },
            ],
        }
    ],
    "chat_template_kwargs": {"enable_thinking": False},
    "max_tokens": 768,
    "temperature": 0.2,
}

started = time.perf_counter()
response = requests.post(
    api_url,
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer local",
    },
    json=payload,
    timeout=600,
)
elapsed = time.perf_counter() - started

if response.status_code != 200:
    raise SystemExit(f"Error {response.status_code}: {response.text}")

result = response.json()
choice = result["choices"][0]
message = choice["message"]
reasoning = message.get("reasoning") or message.get("reasoning_content")

print(f"Response: {elapsed:.2f}s")
print(f"Finish reason: {choice.get('finish_reason')}")
if reasoning:
    print("\nReasoning:")
    print(reasoning)
print("\nAnswer:")
print(message.get("content") or "")
print("\nUsage:")
print(result.get("usage", {}))

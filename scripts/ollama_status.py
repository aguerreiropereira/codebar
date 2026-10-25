#!/usr/bin/env python3
"""Report Ollama local runtime state, not a cloud quota percentage."""
import json
import urllib.request

from metric import emit_metric, make_metric, unavailable


def get_json(path):
    request = urllib.request.Request(f"http://127.0.0.1:11434{path}")
    with urllib.request.urlopen(request, timeout=1) as response:
        return json.loads(response.read().decode("utf-8"))


def collect_ollama_metric():
    try:
        running = get_json("/api/ps").get("models", [])
        if running:
            models = [{
                "name": model.get("name", "local"),
                "size_vram": model.get("size_vram", 0),
            } for model in running]
            primary = models[0]
            size = primary.get("size_vram", 0)
            suffix = f" ({round(size / (1024 ** 3), 1)}G)" if size else " (Ativo)"
            return make_metric(
                "ollama", "local_runtime", "ollama_local_api",
                f"{primary['name']}{suffix}", models=models,
            )

        installed = get_json("/api/tags").get("models", [])
        names = [model.get("name", "local") for model in installed]
        badge = f"Pronto · {len(names)} modelos" if names else "Pronto"
        return make_metric(
            "ollama", "local_runtime", "ollama_local_api", badge,
            state="idle", models=names,
        )
    except Exception:
        return unavailable("ollama", "Offline", "ollama_local_api")


if __name__ == "__main__":
    emit_metric(collect_ollama_metric())

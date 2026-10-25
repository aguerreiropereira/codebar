#!/usr/bin/env python3
"""Read Claude Desktop's local plan usage history when it is available."""
import json
import os

from metric import emit_metric, make_metric, unavailable


def load_app_settings():
    path = os.path.expanduser("~/Library/Application Support/CodeTouchBar/settings.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def collect_claude_metric():
    history = os.path.expanduser("~/Library/Application Support/Claude/plan-usage-history.json")
    try:
        with open(history, "r", encoding="utf-8") as f:
            data = json.load(f)
        samples = data.get("samples", [])
        if not samples or not isinstance(samples[-1], dict):
            return unavailable("claude", "Cota indisponível", "claude_desktop_history")

        usage = samples[-1].get("u", {})
        windows = []
        for field, name in (("fh", "session"), ("sd", "weekly")):
            value = usage.get(field)
            if isinstance(value, (int, float)):
                windows.append({"name": name, "used_percent": float(value),
                                "remaining_percent": max(0.0, 100.0 - float(value))})
        if not windows:
            return unavailable("claude", "Cota indisponível", "claude_desktop_history")

        settings = load_app_settings()
        preference = settings.get("limitWindow", "auto")
        if preference == "weekly":
            chosen = next((w for w in windows if w["name"] == "weekly"), windows[-1])
        elif preference == "session":
            chosen = next((w for w in windows if w["name"] == "session"), windows[0])
        else:
            chosen = max(windows, key=lambda w: w["used_percent"])

        suffix = " sem" if chosen["name"] == "weekly" else " ses"
        badge = f"{int(round(chosen['used_percent']))}%{suffix}"
        try:
            sample_time = os.path.getmtime(history)
        except OSError:
            sample_time = None
        return make_metric(
            "claude", "quota", "claude_desktop_history_private", badge,
            windows=windows, selected_window=chosen["name"],
            observed_at=sample_time, endpoint_class="local_private_file",
        )
    except FileNotFoundError:
        return unavailable("claude", "Cota indisponível", "claude_desktop_history")
    except Exception:
        return unavailable("claude", "Cota indisponível", "claude_desktop_history")


if __name__ == "__main__":
    emit_metric(collect_claude_metric())

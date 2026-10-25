#!/usr/bin/env python3
"""Read Claude Code plan usage captured through its supported status-line hook."""
import json
import os
import time

from metric import emit_metric, make_metric, unavailable


STALE_AFTER_SECONDS = 2 * 60 * 60


def load_app_settings():
    path = os.path.expanduser("~/Library/Application Support/CodeTouchBar/settings.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def collect_claude_metric():
    path = os.path.expanduser("~/Library/Application Support/CodeTouchBar/claude-code-usage.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        rate_limits = data.get("rate_limits", {})
        windows = []
        for field, name in (("five_hour", "session"), ("seven_day", "weekly")):
            window = rate_limits.get(field)
            used = window.get("used_percentage") if isinstance(window, dict) else None
            if isinstance(used, (int, float)):
                windows.append({
                    "name": name,
                    "used_percent": float(used),
                    "remaining_percent": max(0.0, 100.0 - float(used)),
                    "resets_at": window.get("resets_at"),
                })
        if not windows:
            return unavailable("claude", "Aguardando dados do Claude Code", "claude_code_statusline")

        settings = load_app_settings()
        preference = settings.get("limitWindow", "auto")
        if preference == "weekly":
            chosen = next((w for w in windows if w["name"] == "weekly"), windows[-1])
        elif preference == "session":
            chosen = next((w for w in windows if w["name"] == "session"), windows[0])
        else:
            chosen = max(windows, key=lambda w: w["used_percent"])

        sample_time = data.get("observed_at")
        if not isinstance(sample_time, (int, float)):
            sample_time = os.path.getmtime(path)
        sample_age = max(0, time.time() - sample_time)
        state = "available" if sample_age <= STALE_AFTER_SECONDS else "stale"
        suffix = " sem" if chosen["name"] == "weekly" else " ses"
        badge = f"{int(round(chosen['used_percent']))}%{suffix}"
        if state == "stale":
            hours = max(1, int(round(sample_age / 3600)))
            badge += f" · CLI sem dados novos há {hours}h"
        return make_metric(
            "claude", "quota", "claude_code_statusline", badge, state=state,
            windows=windows, selected_window=chosen["name"],
            observed_at=sample_time, sample_age_seconds=int(sample_age),
            stale_after_seconds=STALE_AFTER_SECONDS,
        )
    except FileNotFoundError:
        return unavailable("claude", "Aguardando dados do Claude Code", "claude_code_statusline")
    except Exception:
        return unavailable("claude", "Dados do Claude Code indisponíveis", "claude_code_statusline")


if __name__ == "__main__":
    emit_metric(collect_claude_metric())

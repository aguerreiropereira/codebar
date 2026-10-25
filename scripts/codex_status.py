#!/usr/bin/env python3
"""Read Codex plan quota directly from the local Codex session."""
import json
import os
import time
import urllib.request

from metric import emit_metric, make_metric, unavailable


def load_app_settings():
    path = os.path.expanduser("~/Library/Application Support/CodeTouchBar/settings.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def format_seconds(seconds):
    if seconds <= 0:
        return "0m"
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{hours}h{minutes:02d}m" if hours else f"{minutes}m"


def collect_codex_metric():
    auth_file = os.path.expanduser("~/.codex/auth.json")
    try:
        with open(auth_file, "r", encoding="utf-8") as f:
            auth = json.load(f)
        tokens = auth.get("tokens", {})
        access_token = tokens.get("access_token")
        account_id = tokens.get("account_id")
        if not access_token:
            return unavailable("codex", "Sem sessão Codex", "codex_auth_file")

        headers = {
            "Authorization": f"Bearer {access_token}",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        }
        if account_id:
            headers["chatgpt-account-id"] = account_id
        req = urllib.request.Request(
            "https://chatgpt.com/backend-api/codex/usage", headers=headers
        )
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode("utf-8"))

        rate_limit = data.get("rate_limit", {})
        windows = []
        for key, name in (("primary_window", "session"), ("secondary_window", "weekly")):
            window = rate_limit.get(key)
            if not isinstance(window, dict):
                continue
            used = window.get("used_percent")
            if used is None:
                continue
            reset_after = window.get("reset_after_seconds")
            windows.append({
                "name": name,
                "used_percent": float(used),
                "remaining_percent": max(0.0, 100.0 - float(used)),
                "reset_after_seconds": reset_after,
            })

        if not windows:
            return unavailable("codex", "Cota indisponível", "codex_session")

        settings = load_app_settings()
        preference = settings.get("limitWindow", "auto")
        if preference == "weekly":
            chosen = next((w for w in windows if w["name"] == "weekly"), windows[-1])
        elif preference == "session":
            chosen = next((w for w in windows if w["name"] == "session"), windows[0])
        else:
            chosen = max(windows, key=lambda w: w["used_percent"])

        badge = f"{int(round(chosen['used_percent']))}%"
        if chosen["name"] == "weekly":
            badge += " sem"
        if settings.get("showResetTime", True) and chosen.get("reset_after_seconds"):
            badge += f" · {format_seconds(chosen['reset_after_seconds'])}"

        return make_metric(
            "codex", "quota", "codex_session_private_endpoint", badge,
            windows=windows, selected_window=chosen["name"],
            endpoint_class="private",
        )
    except FileNotFoundError:
        return unavailable("codex", "Sem sessão Codex", "codex_auth_file")
    except Exception:
        return unavailable("codex", "Cota indisponível", "codex_session_private_endpoint")


if __name__ == "__main__":
    emit_metric(collect_codex_metric())

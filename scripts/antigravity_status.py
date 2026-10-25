#!/usr/bin/env python3
"""
Modern Antigravity status badge & quota collector for Touch Bar.
Connects directly to the live Antigravity IDE language server process,
extracts real user quota (5-hour and weekly limits), calculates reset countdowns,
and caches data for high resilience.
"""
import subprocess
import re
import urllib.request
import ssl
import json
import os
import sys
import time
import datetime

from metric import emit_metric, make_metric, unavailable

SETTINGS_PATH = os.path.expanduser("~/Library/Application Support/CodeTouchBar/settings.json")
CACHE_DIR = os.path.expanduser("~/Library/Application Support/CodeTouchBar")
CACHE_FILE = os.path.join(CACHE_DIR, "antigravity_usage.json")

def load_app_settings():
    if os.path.exists(SETTINGS_PATH):
        try:
            with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
                settings = json.load(f)
                if settings.get("antigravityMode") == "steps":
                    settings["antigravityMode"] = "auto"
                return settings
        except Exception:
            pass
    return {}

def format_seconds(seconds):
    if seconds <= 0:
        return "0m"
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h{minutes:02d}m"
    return f"{minutes}m"

def save_cache(data):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return None

def fetch_live_quota():
    """
    Scans running processes for the real Antigravity Language Server,
    retrieves UserQuotaSummary via local HTTPS endpoint.
    """
    try:
        ps_out = subprocess.check_output(["ps", "-Ao", "pid,command"], timeout=2).decode("latin1")
    except Exception:
        return None

    # Sort matching lines so that real IDE processes (with ide_version or antigravity) come first
    candidates = []
    for line in ps_out.splitlines():
        if "language_server" in line and "--csrf_token" in line and "grep" not in line:
            # Score candidates: prefer real Antigravity IDE over dummy instances
            score = 0
            if "override_ide_version" in line:
                score += 10
            if "host_bridge_url" in line:
                score += 10
            if "--app_data_dir antigravity" in line:
                score += 5
            candidates.append((score, line))

    candidates.sort(key=lambda x: x[0], reverse=True)

    for _, line in candidates:
        m_csrf = re.search(r"--csrf_token\s+([a-zA-Z0-9\-]+)", line)
        if not m_csrf:
            continue
        csrf = m_csrf.group(1)
        pid = line.strip().split()[0]

        try:
            lsof_out = subprocess.check_output(["lsof", "-Pan", "-p", pid, "-iTCP", "-sTCP:LISTEN"], timeout=2).decode("latin1")
        except Exception:
            continue

        ports = re.findall(r":(\d+)\s+\(LISTEN\)", lsof_out)
        for port in ports:
            url = f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            req = urllib.request.Request(
                url,
                data=json.dumps({"forceRefresh": False}).encode("utf-8"),
                headers={"Content-Type": "application/json", "x-codeium-csrf-token": csrf}
            )
            try:
                with urllib.request.urlopen(req, context=ctx, timeout=1.8) as r:
                    res = json.loads(r.read().decode())
                    groups = res.get("response", {}).get("groups", [])
                    if groups:
                        return parse_quota_groups(groups)
            except Exception:
                continue

    return None

def parse_quota_groups(groups):
    """
    Extracts 5-hour and weekly quota from groups.
    Prioritizes the active group (the one with non-zero usage or 'Gemini Models').
    """
    best_5h = None
    best_weekly = None
    chosen_group = None
    max_used = -1.0

    for g in groups:
        g_name = g.get("displayName", "Padrão")
        cur_5h = None
        cur_weekly = None

        for b in g.get("buckets", []):
            win = b.get("window")
            rem = float(b.get("remainingFraction", 1.0))
            used = max(0.0, min(1.0, 1.0 - rem))
            res_time = b.get("resetTime")

            item = {
                "remainingFraction": rem,
                "usedFraction": used,
                "usedPct": int(round(used * 100)),
                "resetTime": res_time,
                "displayName": b.get("displayName", win)
            }

            if win == "5h":
                cur_5h = item
            elif win == "weekly":
                cur_weekly = item

        # Evaluate usage level for group selection
        usage_score = 0.0
        if cur_5h:
            usage_score += cur_5h["usedFraction"]
        if cur_weekly:
            usage_score += cur_weekly["usedFraction"]

        if "gemini" in g_name.lower():
            usage_score += 0.01  # slight bias towards Gemini models

        if usage_score > max_used or chosen_group is None:
            max_used = usage_score
            chosen_group = g_name
            best_5h = cur_5h
            best_weekly = cur_weekly

    result = {
        "group": chosen_group,
        "five_hour": best_5h,
        "weekly": best_weekly,
        "timestamp": time.time()
    }
    save_cache(result)
    return result

def get_antigravity_metric():
    settings = load_app_settings()
    show_reset = settings.get("showResetTime", True)
    pref_window = settings.get("limitWindow", "auto")

    # Read the IDE's local Language Server; cached values are kept as an
    # explicit stale state and never presented as a fresh measurement.
    quota = fetch_live_quota()
    is_cached = not quota
    if is_cached:
        quota = load_cache()
    if not quota:
        return unavailable("antigravity", "Indisponível", "antigravity_language_server")

    windows = []
    for name, key in (("session", "five_hour"), ("weekly", "weekly")):
        bucket = quota.get(key)
        if isinstance(bucket, dict) and bucket.get("usedPct") is not None:
            windows.append({
                "name": name,
                "used_percent": float(bucket["usedPct"]),
                "remaining_percent": float(bucket.get("remainingFraction", 1.0)) * 100,
                "reset_at": bucket.get("resetTime"),
            })
    if not windows:
        return unavailable("antigravity", "Indisponível", "antigravity_language_server")

    if pref_window == "weekly":
        chosen = next((w for w in windows if w["name"] == "weekly"), windows[-1])
    else:
        chosen = next((w for w in windows if w["name"] == "session"), windows[0])

    badge = f"{int(round(chosen['used_percent']))}%"
    if chosen["name"] == "weekly":
        badge += " sem"
    reset_time = chosen.get("reset_at")
    if show_reset and reset_time:
        try:
            dt = datetime.datetime.fromisoformat(reset_time.replace("Z", "+00:00"))
            delta = dt.timestamp() - time.time()
            if delta > 0:
                badge += f" · {format_seconds(delta)}"
        except (TypeError, ValueError):
            pass

    observed_at = quota.get("timestamp")
    age = max(0, int(time.time() - observed_at)) if observed_at else None
    state = "stale" if is_cached else "available"
    if is_cached:
        age_label = format_seconds(age) if age is not None else "idade desconhecida"
        badge += f" · cache {age_label}"
    return make_metric(
        "antigravity", "quota", "antigravity_language_server", badge,
        state=state, windows=windows, selected_window=chosen["name"],
        cached=is_cached, cache_age_seconds=age,
        endpoint_class="local_private_protocol",
    )

if __name__ == "__main__":
    emit_metric(get_antigravity_metric())

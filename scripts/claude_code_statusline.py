#!/usr/bin/env python3
"""Persist only Claude Code rate-limit fields for CodeTouchBar."""
import hashlib
import json
import os
import sys
import tempfile
import time


APP_SUPPORT = os.path.expanduser("~/Library/Application Support/CodeTouchBar")
CACHE_PATH = os.path.join(APP_SUPPORT, "claude-code-usage.json")


def read_payload():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def persist_rate_limits(payload):
    limits = payload.get("rate_limits")
    if not isinstance(limits, dict):
        return None

    normalized = {}
    for field in ("five_hour", "seven_day"):
        window = limits.get(field)
        if not isinstance(window, dict):
            continue
        used = window.get("used_percentage")
        if isinstance(used, (int, float)):
            normalized[field] = {
                "used_percentage": float(used),
                "resets_at": window.get("resets_at"),
            }
    if not normalized:
        return None

    signature_input = json.dumps(
        {"prompt_id": payload.get("prompt_id"), "rate_limits": normalized},
        sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")
    signature = hashlib.sha256(signature_input).hexdigest()
    observed_at = time.time()
    try:
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            previous = json.load(f)
        if previous.get("signature") == signature:
            observed_at = previous.get("observed_at", observed_at)
    except (OSError, ValueError, AttributeError):
        pass

    os.makedirs(APP_SUPPORT, mode=0o700, exist_ok=True)
    cache = {
        "rate_limits": normalized,
        "signature": signature,
        "observed_at": observed_at,
    }
    descriptor, temporary = tempfile.mkstemp(prefix="claude-code-usage-", dir=APP_SUPPORT)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as f:
            json.dump(cache, f, separators=(",", ":"))
            f.write("\n")
        os.replace(temporary, CACHE_PATH)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return normalized


def main():
    payload = read_payload()
    limits = persist_rate_limits(payload) if payload else None
    if not limits:
        print("Claude: aguardando primeira resposta")
        return

    parts = []
    five_hour = limits.get("five_hour", {}).get("used_percentage")
    seven_day = limits.get("seven_day", {}).get("used_percentage")
    if five_hour is not None:
        parts.append(f"5h {five_hour:.0f}%")
    if seven_day is not None:
        parts.append(f"7d {seven_day:.0f}%")
    print("Claude " + " · ".join(parts))


if __name__ == "__main__":
    main()

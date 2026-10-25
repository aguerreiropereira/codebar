#!/usr/bin/env python3
"""Shared result format for local provider collectors."""
import json
import sys
import time


def make_metric(provider, kind, source, badge, state="available", **values):
    result = {
        "provider": provider,
        "kind": kind,
        "state": state,
        "source": source,
        "observed_at": time.time(),
        "badge": badge,
    }
    result.update(values)
    return result


def unavailable(provider, message="Indisponível", source="none"):
    return make_metric(provider, "unavailable", source, message, state="unavailable")


def emit_metric(result):
    if "--json" in sys.argv[1:]:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(result.get("badge", "Indisponível"))

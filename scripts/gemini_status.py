#!/usr/bin/env python3
"""Gemini Apps personal quota has no documented local usage API."""
from metric import emit_metric, unavailable


if __name__ == "__main__":
    emit_metric(unavailable(
        "gemini",
        "Cota indisponível",
        "no_documented_gemini_apps_usage_api",
    ))

#!/usr/bin/env python3
"""Perplexity Pro/Max personal quota has no documented read API."""
from metric import emit_metric, unavailable


if __name__ == "__main__":
    emit_metric(unavailable(
        "perplexity",
        "Cota indisponível",
        "no_documented_perplexity_subscription_usage_api",
    ))

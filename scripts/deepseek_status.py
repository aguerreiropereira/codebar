#!/usr/bin/env python3
"""Read DeepSeek API account balance; this is not a chat-plan quota."""
import json
import os
import urllib.request

from metric import emit_metric, make_metric, unavailable


def collect_deepseek_metric():
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        return unavailable("deepseek", "API sem chave", "deepseek_api_balance")

    request = urllib.request.Request(
        "https://api.deepseek.com/user/balance",
        headers={"Accept": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=4) as response:
            data = json.loads(response.read().decode("utf-8"))
        balances = data.get("balance_infos", [])
        if not isinstance(balances, list) or not balances:
            return unavailable("deepseek", "Saldo indisponível", "deepseek_api_balance")

        amounts = []
        for entry in balances:
            if not isinstance(entry, dict):
                continue
            try:
                amount = float(entry.get("total_balance"))
            except (TypeError, ValueError):
                continue
            amounts.append({
                "currency": entry.get("currency", ""),
                "total": amount,
                "granted": entry.get("granted_balance"),
                "topped_up": entry.get("topped_up_balance"),
            })
        if not amounts:
            return unavailable("deepseek", "Saldo indisponível", "deepseek_api_balance")

        display = " / ".join(f"{item['currency']} {item['total']:.2f}" for item in amounts)
        state = "available" if data.get("is_available") else "depleted"
        badge = display if state == "available" else f"Saldo baixo · {display}"
        return make_metric(
            "deepseek", "balance", "deepseek_api_balance", badge,
            state=state, balances=amounts,
        )
    except Exception:
        return unavailable("deepseek", "Saldo indisponível", "deepseek_api_balance")


if __name__ == "__main__":
    emit_metric(collect_deepseek_metric())

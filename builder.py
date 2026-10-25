#!/usr/bin/env python3
"""
Builder module to compile high-level user settings into MTMR items.json.
"""
import os
import json
import base64
import shlex
import sys

ASSETS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
CONFIG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config")
SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts")

DEFAULT_SETTINGS = {
    "widgets": {
        "escape": {"enabled": True, "width": 54},
        "codex": {"enabled": True, "refresh": 30, "bordered": True, "url": "https://chatgpt.com"},
        "claude": {"enabled": True, "refresh": 30, "bordered": True, "url": "https://claude.ai"},
        "antigravity": {"enabled": True, "refresh": 30, "bordered": True, "url": ""},
        "brightness": {"enabled": False},
        "volume": {"enabled": True},
        "battery": {"enabled": True},
        "clock": {"enabled": True, "format": "HH:mm"},
        "settings": {"enabled": True}
    },
    "order": ["escape", "codex", "claude", "antigravity", "settings", "brightness", "volume", "battery", "clock"]
}

def get_base64_icon(filename):
    path = os.path.join(ASSETS_DIR, filename)
    if os.path.exists(path):
        with open(path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")
    return None

def build_items_json(settings):
    widgets = settings.get("widgets", DEFAULT_SETTINGS["widgets"])
    order = settings.get("order", DEFAULT_SETTINGS["order"])

    codex_icon = get_base64_icon("codex.png")
    claude_icon = get_base64_icon("claude.png")
    agy_icon = get_base64_icon("antigravity.png")

    items = []

    for widget_id in order:
        cfg = widgets.get(widget_id, {})
        if not cfg.get("enabled", True):
            continue

        if widget_id == "escape":
            items.append({
                "type": "escape",
                "width": cfg.get("width", 54),
                "align": "left"
            })

        elif widget_id == "codex":
            item = {
                "type": "shellScriptTitledButton",
                "refreshInterval": cfg.get("refresh", 30),
                "source": {
                    "inline": f"{shlex.quote(sys.executable)} {shlex.quote(os.path.join(SCRIPTS_DIR, 'codex_status.py'))}"
                },
                "bordered": cfg.get("bordered", True),
                "align": "left"
            }
            if codex_icon:
                item["image"] = {"base64": codex_icon}
            if cfg.get("url"):
                item["action"] = "openUrl"
                item["url"] = cfg["url"]
            items.append(item)

        elif widget_id == "claude":
            item = {
                "type": "shellScriptTitledButton",
                "refreshInterval": cfg.get("refresh", 30),
                "source": {
                    "inline": f"{shlex.quote(sys.executable)} {shlex.quote(os.path.join(SCRIPTS_DIR, 'claude_status.py'))}"
                },
                "bordered": cfg.get("bordered", True),
                "align": "left"
            }
            if claude_icon:
                item["image"] = {"base64": claude_icon}
            if cfg.get("url"):
                item["action"] = "openUrl"
                item["url"] = cfg["url"]
            items.append(item)

        elif widget_id == "antigravity":
            item = {
                "type": "shellScriptTitledButton",
                "refreshInterval": cfg.get("refresh", 30),
                "source": {
                    "inline": f"{shlex.quote(sys.executable)} {shlex.quote(os.path.join(SCRIPTS_DIR, 'antigravity_status.py'))}"
                },
                "bordered": cfg.get("bordered", True),
                "align": "left"
            }
            if agy_icon:
                item["image"] = {"base64": agy_icon}
            if cfg.get("url"):
                item["action"] = "openUrl"
                item["url"] = cfg["url"]
            items.append(item)

        elif widget_id == "settings":
            items.append({
                "type": "staticButton",
                "title": "⚙️",
                "action": "openUrl",
                "url": "http://127.0.0.1:4588",
                "bordered": True,
                "align": "right",
                "width": 38
            })

        elif widget_id == "brightness":
            items.append({"type": "brightnessDown", "width": 32, "bordered": False, "align": "right"})
            items.append({"type": "brightnessUp", "width": 32, "bordered": False, "align": "right"})

        elif widget_id == "volume":
            items.append({"type": "volume", "align": "right"})

        elif widget_id == "battery":
            items.append({"type": "battery", "align": "right", "bordered": False})

        elif widget_id == "clock":
            items.append({
                "type": "timeButton",
                "formatTemplate": cfg.get("format", "HH:mm"),
                "align": "right",
                "bordered": False
            })

    return items


def write_items_file():
    settings_path = os.path.join(CONFIG_DIR, "settings.json")
    if os.path.exists(settings_path):
        with open(settings_path, "r", encoding="utf-8") as settings_file:
            settings = json.load(settings_file)
    else:
        settings = DEFAULT_SETTINGS

    os.makedirs(CONFIG_DIR, exist_ok=True)
    items_path = os.path.join(CONFIG_DIR, "items.json")
    with open(items_path, "w", encoding="utf-8") as items_file:
        json.dump(build_items_json(settings), items_file, indent=2)
    return items_path


if __name__ == "__main__":
    print(write_items_file())

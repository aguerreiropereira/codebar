#!/usr/bin/env python3
"""Install CodeTouchBar's local Claude Code status-line bridge."""
import json
import os
import shutil
import sys
import tempfile


HOME = os.path.expanduser("~")
APP_SUPPORT = os.path.join(HOME, "Library", "Application Support", "CodeTouchBar")
SETTINGS_PATH = os.path.join(HOME, ".claude", "settings.json")
SOURCE_SCRIPT = os.path.join(os.path.dirname(__file__), "claude_code_statusline.py")
INSTALLED_SCRIPT = os.path.join(APP_SUPPORT, "claude_code_statusline.py")


def atomic_write_json(path, value, mode=0o600):
    directory = os.path.dirname(path)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".codetouchbar-", dir=directory)
    try:
        os.fchmod(descriptor, mode)
        with os.fdopen(descriptor, "w", encoding="utf-8") as f:
            json.dump(value, f, ensure_ascii=False, indent=2)
            f.write("\n")
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def main():
    os.makedirs(APP_SUPPORT, mode=0o700, exist_ok=True)
    shutil.copyfile(SOURCE_SCRIPT, INSTALLED_SCRIPT)
    os.chmod(INSTALLED_SCRIPT, 0o700)

    settings = {}
    mode = 0o600
    if os.path.exists(SETTINGS_PATH):
        stat = os.stat(SETTINGS_PATH)
        mode = stat.st_mode & 0o777
        with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
            settings = json.load(f)
    if not isinstance(settings, dict):
        raise ValueError("~/.claude/settings.json precisa conter um objeto JSON")
    if settings.get("statusLine"):
        print("Integração não instalada: já existe uma configuração statusLine em ~/.claude/settings.json.", file=sys.stderr)
        print("A configuração existente foi preservada.", file=sys.stderr)
        return 2

    settings["statusLine"] = {
        "type": "command",
        "command": f'"{sys.executable}" "{INSTALLED_SCRIPT}"',
        "refreshInterval": 60,
    }
    atomic_write_json(SETTINGS_PATH, settings, mode)
    print("Integração Claude Code → CodeTouchBar instalada.")
    print("Abra ou retome uma sessão do Claude Code e aguarde a primeira resposta para carregar os limites.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

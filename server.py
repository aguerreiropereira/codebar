#!/usr/bin/env python3
"""
CodeTouchBar Configuration Server.
Serves a sleek settings UI and API to control MTMR Touch Bar configuration.
"""
import os
import sys
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from builder import DEFAULT_SETTINGS, build_items_json

PORT = 4588
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_FILE = os.path.join(PROJECT_DIR, "config", "settings.json")
ITEMS_FILE = os.path.join(PROJECT_DIR, "config", "items.json")
MTMR_ITEMS_FILE = os.path.expanduser("~/Library/Application Support/MTMR/items.json")
WEB_DIR = os.path.join(PROJECT_DIR, "web")

def load_settings():
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return DEFAULT_SETTINGS

def save_settings(settings):
    if not isinstance(settings, dict):
        raise ValueError("As configurações precisam ser um objeto JSON.")
    widgets = settings.get("widgets")
    order = settings.get("order")
    if not isinstance(widgets, dict) or not isinstance(order, list):
        raise ValueError("As configurações precisam conter 'widgets' e 'order'.")
    if any(not isinstance(widget_id, str) for widget_id in order):
        raise ValueError("A ordem dos widgets contém um identificador inválido.")
    if any(not isinstance(config, dict) for config in widgets.values()):
        raise ValueError("Cada configuração de widget precisa ser um objeto.")

    # Validate and build before writing, so malformed JSON cannot replace the
    # last working settings file and then fail partway through the save.
    items = build_items_json(settings)
    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, indent=2)

    with open(ITEMS_FILE, "w") as f:
        json.dump(items, f, indent=2)

    os.makedirs(os.path.dirname(MTMR_ITEMS_FILE), exist_ok=True)
    with open(MTMR_ITEMS_FILE, "w") as f:
        json.dump(items, f, indent=2)

    # Reload MTMR
    try:
        subprocess.run(["killall", "MTMR"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        subprocess.run(["open", "-a", "MTMR"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
    except Exception as e:
        print("Error reloading MTMR:", e)

def get_live_data():
    scripts_dir = os.path.join(PROJECT_DIR, "scripts")
    scripts = [
        ("codex", "codex_status.py"),
        ("claude", "claude_status.py"),
        ("antigravity", "antigravity_status.py")
    ]

    def read_status(name, script):
        path = os.path.join(scripts_dir, script)
        try:
            result = subprocess.run(
                [sys.executable, path],
                capture_output=True,
                text=True,
                timeout=3,
                check=True,
            )
            return name, result.stdout.strip()
        except Exception:
            return name, "--"

    with ThreadPoolExecutor(max_workers=len(scripts)) as executor:
        return dict(executor.map(lambda item: read_status(*item), scripts))

class SettingsHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith("/api/icon/"):
            icon_name = self.path.split("/")[-1] + ".png"
            icon_path = os.path.join(PROJECT_DIR, "assets", icon_name)
            if os.path.exists(icon_path):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                with open(icon_path, "rb") as f:
                    self.wfile.write(f.read())
                return
            self.send_response(404)
            self.end_headers()
            return

        if self.path == "/api/settings":
            settings = load_settings()
            live = get_live_data()
            response = {"settings": settings, "live": live}
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode("utf-8"))
            return

        if self.path == "/api/live":
            live = get_live_data()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(live).encode("utf-8"))
            return

        return super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/icon/"):
            icon_name = self.path.split("/")[-1] + ".png"
            icon_path = os.path.join(PROJECT_DIR, "assets", icon_name)
            if os.path.exists(icon_path):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                with open(icon_path, "rb") as f:
                    self.wfile.write(f.read())
                return
            self.send_response(404)
            self.end_headers()
            return

        if self.path == "/api/settings":
            # This local endpoint changes settings and restarts MTMR. Accept
            # writes only from the documented same-origin UI.
            if self.headers.get("Origin") != f"http://127.0.0.1:{PORT}":
                self.send_error(403, "Origem não autorizada")
                return

            try:
                content_length = int(self.headers.get("Content-Length", 0))
                if content_length <= 0 or content_length > 1024 * 1024:
                    raise ValueError("Tamanho do corpo inválido.")
                body = self.rfile.read(content_length).decode("utf-8")
                new_settings = json.loads(body)
                save_settings(new_settings)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True}).encode("utf-8"))
            except Exception as e:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
            return

        self.send_response(404)
        self.end_headers()

def run_server():
    server_address = ("127.0.0.1", PORT)
    httpd = ThreadingHTTPServer(server_address, SettingsHandler)
    print(f"🎛️ CodeTouchBar App rodando em: http://127.0.0.1:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == "__main__":
    run_server()

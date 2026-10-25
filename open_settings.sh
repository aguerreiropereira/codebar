#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PORT=4588
PYTHON="$(command -v python3)"

if [ -z "$PYTHON" ]; then
    echo "Python 3 não foi encontrado. Instale o Python 3 e tente novamente."
    exit 1
fi

# Check if server is already running on port 4588
if ! lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "⚡ Iniciando servidor CodeTouchBar Studio..."
    nohup "$PYTHON" "$DIR/server.py" >/dev/null 2>&1 &
    sleep 1
fi

echo "🌐 Abrindo painel de configuração..."
open "http://127.0.0.1:$PORT"

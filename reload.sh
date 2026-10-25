#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PYTHON="$(command -v python3)"

if [ -z "$PYTHON" ]; then
    echo "Python 3 não foi encontrado. Instale o Python 3 e tente novamente."
    exit 1
fi

echo "🔄 Atualizando configuração do MTMR..."
mkdir -p "$HOME/Library/Application Support/MTMR"
"$PYTHON" "$DIR/builder.py"
cp "$DIR/config/items.json" "$HOME/Library/Application Support/MTMR/items.json"

echo "⚡ Reiniciando MTMR na Touch Bar..."
killall MTMR 2>/dev/null || true
sleep 1
open -a MTMR

echo "✅ Pronto! Touch Bar atualizada."

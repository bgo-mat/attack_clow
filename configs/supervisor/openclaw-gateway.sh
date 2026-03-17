#!/bin/bash

utils=/opt/supervisor-scripts/utils
. "${utils}/logging.sh"
. "${utils}/environment.sh"

export OLLAMA_API_KEY="ollama-local"

# Wait for Ollama to be ready
echo "Waiting for Ollama API..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "Ollama ready"
        break
    fi
    sleep 2
done

echo "Starting OpenClaw Gateway on port 18790..."
export PATH="/opt/nvm/versions/node/v24.12.0/bin:$PATH"
exec openclaw gateway --port 18790 2>&1

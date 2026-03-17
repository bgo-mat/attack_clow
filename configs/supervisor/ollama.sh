#!/bin/bash

utils=/opt/supervisor-scripts/utils
. "${utils}/logging.sh"
. "${utils}/environment.sh"

export OLLAMA_HOST="0.0.0.0:11434"

echo "Starting Ollama..."
exec /usr/local/bin/ollama serve 2>&1

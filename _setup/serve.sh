#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${STATIC_SERVER_HOST:-127.0.0.1}"
PORT="${1:-${STATIC_SERVER_PORT:-8080}}"

printf 'Serving %s at http://%s:%s/pear/\n' "$ROOT_DIR" "$HOST" "$PORT"
exec php -S "$HOST:$PORT" -t "$ROOT_DIR" "$ROOT_DIR/_setup/serverRouter.php"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== dotphrase smoke =="
swift --version

echo "-- swift build"
swift build -c debug

echo "-- CLI basic search"
OUT="$(swift run -c debug dotphrase gm)"
echo "$OUT"

echo "$OUT" | grep -q "\\.gmail" || {
  echo "ERROR: expected to find .gmail in output" >&2
  exit 1
}

echo "OK"

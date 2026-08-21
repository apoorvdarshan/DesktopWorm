#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
swift run -c release DesktopWorm --selftest
PREVIEW_PATH="$ROOT_DIR/.build/DesktopWorm-preview.png"
LAB_PREVIEW_PATH="$ROOT_DIR/.build/DesktopWorm-lab-preview.png"
swift run -c release DesktopWorm --render-preview "$PREVIEW_PATH"
swift run -c release DesktopWorm --render-lab-preview "$LAB_PREVIEW_PATH"
test -s "$PREVIEW_PATH"
test -s "$LAB_PREVIEW_PATH"
/usr/bin/sips -g pixelWidth -g pixelHeight "$PREVIEW_PATH"
/usr/bin/sips -g pixelWidth -g pixelHeight "$LAB_PREVIEW_PATH"

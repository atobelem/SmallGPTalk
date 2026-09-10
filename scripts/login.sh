#!/bin/bash
set -euo pipefail
export SMALLGPTALK_WORK_DIR="${SMALLGPTALK_WORK_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.build/live}"
export SMALLGPTALK_LOAD_GROUP=OpenAI
source "$(dirname "$0")/common.sh"
bash "$SMALLGPTALK_ROOT/scripts/load.sh"
cd "$SMALLGPTALK_WORK_DIR"
"$SMALLGPTALK_VM" --headless "$SMALLGPTALK_WORK_IMAGE" st "$SMALLGPTALK_ROOT/scripts/live-login.st"

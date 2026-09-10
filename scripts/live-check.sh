#!/bin/bash
set -euo pipefail
if [[ -z "${SMALLGPTALK_MODEL:-}" ]]; then
  echo 'Set SMALLGPTALK_MODEL to an explicit identifier from the account catalog.' >&2
  exit 1
fi
export SMALLGPTALK_WORK_DIR="${SMALLGPTALK_WORK_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.build/live-check}"
export SMALLGPTALK_LOAD_GROUP=default
source "$(dirname "$0")/common.sh"
bash "$SMALLGPTALK_ROOT/scripts/load.sh"
cd "$SMALLGPTALK_WORK_DIR"
"$SMALLGPTALK_VM" --headless "$SMALLGPTALK_WORK_IMAGE" st "$SMALLGPTALK_ROOT/scripts/live-acceptance.st"

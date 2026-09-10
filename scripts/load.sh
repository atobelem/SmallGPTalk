#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
smallgptalk_prepare_image
cd "$SMALLGPTALK_WORK_DIR"
"$SMALLGPTALK_VM" --headless "$SMALLGPTALK_WORK_IMAGE" st "$SMALLGPTALK_ROOT/scripts/load.st"
echo "Loaded image: $SMALLGPTALK_WORK_IMAGE"

#!/bin/bash
set -euo pipefail
export SMALLGPTALK_LOAD_GROUP=Tests
source "$(dirname "$0")/common.sh"
bash "$SMALLGPTALK_ROOT/scripts/load.sh"
cd "$SMALLGPTALK_WORK_DIR"
"$SMALLGPTALK_VM" --headless "$SMALLGPTALK_WORK_IMAGE" test \
  --junit-xml-output --fail-on-failure 'SmallGPTalk-Tests'

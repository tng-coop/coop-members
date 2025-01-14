#!/usr/bin/env bash

# Usage:
#   ./migrate.sh         # autodetect local vs GHA
#   ./migrate.sh neon    # use .gmrc.neon.js
#   ./migrate.sh local   # force .gmrc
#   ./migrate.sh gha     # force .gmrc.gha

# 1) CLI arg
MODE="$1"

# 2) Detect GitHub Actions
IS_GHA="$GITHUB_ACTIONS"  # "true" in GHA, else empty

CONFIG=".gmrc"  # default

if [ "$MODE" = "neon" ]; then
  CONFIG=".gmrc.neon.js"
elif [ "$MODE" = "gha" ]; then
  CONFIG=".gmrc.gha"
elif [ "$MODE" = "local" ]; then
  CONFIG=".gmrc"
elif [ -z "$MODE" ] && [ "$IS_GHA" = "true" ]; then
  CONFIG=".gmrc.gha"
fi

echo "Using config: $CONFIG"
npx graphile-migrate migrate --config "$CONFIG"

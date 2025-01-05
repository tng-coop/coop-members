#!/usr/bin/env sh

# Exit immediately on error
set -e

# Execute the graphile-migrate command with the given config
npx graphile-migrate migrate --config .gmrc.neon.js

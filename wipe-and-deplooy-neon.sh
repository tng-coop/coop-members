#!/usr/bin/env bash
#
# wipe-and-deploy-neon.sh
#
# This script drops the existing "public" schema in a Neon-hosted Postgres database,
# recreates it, and runs your migrations (e.g., Graphile Migrate) to rebuild tables.
#
# Usage:
#   chmod +x wipe-and-deploy-neon.sh
#   ./wipe-and-deploy-neon.sh
#
# Environment variables required (set them in ~/.bashrc or similar):
#   NEON_USER      (e.g., your Neon username)
#   NEON_PASSWORD  (the Neon user password - not stored in code/comments)
#   NEON_HOST      (the Neon host)
#   NEON_DB        (the Neon DB name)
#   SSLMODE        (optional, defaults to 'require')
#
# NOTE: Make sure 'psql' is installed, and 'npx graphile-migrate' (or your migration tool)
#       is available in your PATH.

set -e  # Exit immediately on error

echo "=== Checking environment variables for Neon... ==="
if [ -z "$NEON_USER" ] || [ -z "$NEON_PASSWORD" ] || [ -z "$NEON_HOST" ] || [ -z "$NEON_DB" ]; then
  echo "ERROR: NEON_USER, NEON_PASSWORD, NEON_HOST, and NEON_DB must be set."
  exit 1
fi

if [ -z "$SSLMODE" ]; then
  SSLMODE="require"
fi

# Use PGPASSWORD to ensure psql doesn't prompt for a password.
export PGPASSWORD="$NEON_PASSWORD"

echo "=== Dropping 'public' schema on Neon (CASCADE) ==="
psql \
  -U "$NEON_USER" \
  -h "$NEON_HOST" \
  -d "$NEON_DB" \
  --set=sslmode="$SSLMODE" \
  -c "DROP SCHEMA IF EXISTS public CASCADE;"

echo "=== Recreating 'public' schema ==="
psql \
  -U "$NEON_USER" \
  -h "$NEON_HOST" \
  -d "$NEON_DB" \
  --set=sslmode="$SSLMODE" \
  -c "CREATE SCHEMA public;"

echo "=== Running migrations (Graphile Migrate, or your tool) ==="
npx graphile-migrate up

echo "=== Done! Neon DB has been wiped and redeployed. ==="

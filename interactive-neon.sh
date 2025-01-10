#!/usr/bin/env bash
set -euo pipefail

# Require that these environment variables are already set:
: "${NEON_USER:?NEON_USER is not set}"
: "${NEON_PASSWORD:?NEON_PASSWORD is not set}"
: "${NEON_HOST:?NEON_HOST is not set}"
: "${NEON_DB:?NEON_DB is not set}"
: "${SSLMODE:?SSLMODE is not set}"

# Export the PGPASSWORD so psql can use it automatically:
export PGPASSWORD="${NEON_PASSWORD}"

psql \
  --host="${NEON_HOST}" \
  --port=5432 \
  --username="${NEON_USER}" \
  --dbname="${NEON_DB}" \
  --set=sslmode="${SSLMODE}"

#!/usr/bin/env bash

# Set default port if not provided
PORT=${PORT:-5000}

echo "Starting PostGraphile server on port $PORT..."

npx postgraphile \
  --connection "postgres://${NEON_USER}:${NEON_PASSWORD}@${NEON_HOST}:5432/${NEON_DB}?sslmode=${SSLMODE}" \
  --schema public \
  --host 0.0.0.0 \
  --port $PORT \
  --default-role anonymous \
  --enhance-graphiql


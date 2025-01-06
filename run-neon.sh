#!/usr/bin/env bash

# Set default port if not provided
PORT=${PORT:-5000}

# Default: do NOT disable GraphiQL
DISABLE_GRAPHIQL=0

# Collect any non-recognized arguments to pass through to postgraphile
POSITIONAL_ARGS=()

# Parse CLI arguments
for arg in "$@"; do
  case $arg in
    --disable-graphiql)
      DISABLE_GRAPHIQL=1
      shift
      ;;
    *)
      # Any other args should be forwarded directly to PostGraphile
      POSITIONAL_ARGS+=("$arg")
      shift
      ;;
  esac
done

echo "Starting PostGraphile server on port $PORT..."

# Decide which GraphiQL option to use
if [ "$DISABLE_GRAPHIQL" = "1" ]; then
  GRAPHIQL_OPTION="--disable-graphiql"
else
  GRAPHIQL_OPTION="--enhance-graphiql"
fi

# Launch PostGraphile
npx postgraphile \
  --connection "postgres://${NEON_USER}:${NEON_PASSWORD}@${NEON_HOST}:5432/${NEON_DB}?sslmode=${SSLMODE}" \
  --schema public \
  --host 0.0.0.0 \
  --port "$PORT" \
  $GRAPHIQL_OPTION \
  "${POSITIONAL_ARGS[@]}"

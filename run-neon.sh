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

# ---------------------------------------------------------------------------
# Neon credentials and DB info (assumed to be set in environment variables):
#   NEON_USER    (defaults to "auth_user" below)
#   NEON_PASSWORD
#   NEON_HOST
#   NEON_DB
#   SSLMODE
#
# For example:
#   export NEON_USER="auth_user"
#   export NEON_PASSWORD="xyz"
#   export NEON_HOST="some-neon-host"
#   export NEON_DB="coop-members"
#   export SSLMODE="require"  # or "prefer", etc.
# ---------------------------------------------------------------------------
NEON_USER=${NEON_USER:-auth_user}
NEON_PASSWORD=${NEON_PASSWORD:-}
NEON_HOST=${NEON_HOST:-"127.0.0.1"}
NEON_DB=${NEON_DB:-"coop-members"}
SSLMODE=${SSLMODE:-require}

# ---------------------------------------------------------------------------
# PostGraphile options for RLS-based approach:
#  - --default-role "app_user" => ensures queries run as "app_user" 
#    instead of trying to SET ROLE from the JWT's "role" field.
#  - --jwt-secret => needed if you want PostGraphile to verify JWTs
#  - --jwt-token-identifier => which composite type identifies your JWT
# ---------------------------------------------------------------------------
DEFAULT_ROLE=${DEFAULT_ROLE:-app_user}
JWT_SECRET=${JWT_SECRET:-SUPER_SECRET_TOKEN}
JWT_TOKEN_IDENTIFIER=${JWT_TOKEN_IDENTIFIER:-public.jwt_token}

echo "Using NEON_USER=$NEON_USER, host=$NEON_HOST, db=$NEON_DB, sslmode=$SSLMODE"
echo "Connecting with default role: $DEFAULT_ROLE"
NEON_USER=auth_user
npx postgraphile \
  --connection "postgres://${NEON_USER}:${NEON_PASSWORD}@${NEON_HOST}:5432/${NEON_DB}?sslmode=${SSLMODE}" \
  --schema public \
  --host 0.0.0.0 \
  --port "$PORT" \
  --default-role "$DEFAULT_ROLE" \
  --jwt-secret "$JWT_SECRET" \
  --jwt-token-identifier "$JWT_TOKEN_IDENTIFIER" \
  $GRAPHIQL_OPTION \
  "${POSITIONAL_ARGS[@]}"

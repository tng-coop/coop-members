#!/usr/bin/env bash
#
# Usage:
#   ./run-postgraphile.sh [--use-neon | neon] [--disable-graphiql] [other PostGraphile args...]
#
# By default, runs locally (via Unix socket). 
# If you pass `--use-neon` or just "neon", it uses the EXACT logic from your old run-neon.sh.

##############################################################################
#                          CLI ARG PARSING
##############################################################################

USE_NEON=0     # default: local
PORT=${PORT:-5000}
DISABLE_GRAPHIQL=0

POSITIONAL_ARGS=()

for arg in "$@"; do
  case $arg in
    --use-neon)
      USE_NEON=1
      shift
      ;;
    neon)
      # Treat bare "neon" as alias for --use-neon
      USE_NEON=1
      shift
      ;;
    --disable-graphiql)
      DISABLE_GRAPHIQL=1
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      shift
      ;;
  esac
done

echo "Starting PostGraphile on port $PORT..."

# Decide which GraphiQL option to use
if [ "$DISABLE_GRAPHIQL" = "1" ]; then
  GRAPHIQL_OPTION="--disable-graphiql"
else
  GRAPHIQL_OPTION="--enhance-graphiql"
fi

##############################################################################
#                          SHARED: JWT / DEFAULT ROLE
##############################################################################

# Same defaults as old scripts
DEFAULT_ROLE=${DEFAULT_ROLE:-app_user}
JWT_SECRET=${JWT_SECRET:-SUPER_SECRET_TOKEN}
JWT_TOKEN_IDENTIFIER=${JWT_TOKEN_IDENTIFIER:-public.jwt_token}

##############################################################################
#                           NEON LOGIC (old run-neon.sh)
##############################################################################
# Because you said "the old script worked," we replicate it literally:

function runNeonLogic() {
  # Recreate your run-neon.sh environment variable logic
  # (minus the disclaimers in comments, just the raw logic).
  DISABLE_GRAPHIQL_LOCAL="$1"
  shift

  # NEON credentials
  NEON_USER=${NEON_USER:-auth_user}
  NEON_PASSWORD=${NEON_PASSWORD:-}
  NEON_HOST=${NEON_HOST:-"127.0.0.1"}
  NEON_DB=${NEON_DB:-"coop-members"}
  SSLMODE=${SSLMODE:-"require"}

  echo "Starting PostGraphile server on port $PORT..."
  # Reuse the local disable-graphiql logic
  if [ "$DISABLE_GRAPHIQL_LOCAL" = "1" ]; then
    GRAPHIQL_OPTION="--disable-graphiql"
  else
    GRAPHIQL_OPTION="--enhance-graphiql"
  fi

  echo "Using NEON_USER=$NEON_USER, host=$NEON_HOST, db=$NEON_DB, sslmode=$SSLMODE"
  echo "Connecting with default role: $DEFAULT_ROLE"

  # Here is the EXACT line that old run-neon.sh had, which overwrote NEON_USER:
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
    "$@"
}

##############################################################################
#                           LOCAL LOGIC (old run-local-postgraphile.sh)
##############################################################################

function runLocalLogic() {
  echo "Starting PostGraphile locally on port $PORT..."

  if [ "$DISABLE_GRAPHIQL" = "1" ]; then
    GRAPHIQL_OPTION="--disable-graphiql"
  else
    GRAPHIQL_OPTION="--enhance-graphiql"
  fi

  # Default values from old run-local-postgraphile.sh
  LOCAL_USER=${LOCAL_USER:-auth_user}
  LOCAL_PASSWORD=${LOCAL_PASSWORD:-}  # Often not needed for local socket
  LOCAL_DB=${LOCAL_DB:-coop-members}
  LOCAL_SOCKET_PATH=${LOCAL_SOCKET_PATH:-/var/run/postgresql}
  SSL_MODE=${SSL_MODE:-disable}

  # Build connection string
  if [ -n "$LOCAL_PASSWORD" ]; then
    CONNECTION_STRING="postgres://${LOCAL_USER}:${LOCAL_PASSWORD}@/${LOCAL_DB}?host=${LOCAL_SOCKET_PATH}&sslmode=${SSL_MODE}"
  else
    CONNECTION_STRING="postgres://${LOCAL_USER}@/${LOCAL_DB}?host=${LOCAL_SOCKET_PATH}&sslmode=${SSL_MODE}"
  fi

  echo "Using Unix domain socket at: ${LOCAL_SOCKET_PATH}"
  echo "Connecting as user: ${LOCAL_USER}, DB: ${LOCAL_DB}"
  echo "Connection string: $CONNECTION_STRING"

  npx postgraphile \
    --connection "$CONNECTION_STRING" \
    --schema public \
    --jwt-secret "$JWT_SECRET" \
    --jwt-token-identifier "$JWT_TOKEN_IDENTIFIER" \
    --default-role "$DEFAULT_ROLE" \
    --host 0.0.0.0 \
    --port "$PORT" \
    $GRAPHIQL_OPTION \
    "${POSITIONAL_ARGS[@]}"
}

##############################################################################
#                           MAIN LOGIC
##############################################################################

if [ "$USE_NEON" = "1" ]; then
  # EXACT old run-neon.sh logic
  runNeonLogic "$DISABLE_GRAPHIQL" "${POSITIONAL_ARGS[@]}"
else
  # EXACT old run-local-postgraphile.sh logic
  runLocalLogic
fi

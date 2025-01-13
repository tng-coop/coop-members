#!/usr/bin/env bash
#
# Usage:
#   ./run-postgraphile.sh [--use-neon | neon] [--disable-graphiql] [other args...]
#
# By default, runs locally (via Unix socket).
# If you pass `--use-neon` or "neon", it uses the same logic as your old run-neon.sh
# (including the NEON_USER=auth_user override). We just refactor the code so
# debug lines don't break the connection string.

##############################################################################
#                            CLI ARG PARSING
##############################################################################

USE_NEON=0
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
      # also treat bare "neon" as an alias for --use-neon
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

# Decide GraphiQL option
if [ "$DISABLE_GRAPHIQL" = "1" ]; then
  GRAPHIQL_OPTION="--disable-graphiql"
else
  GRAPHIQL_OPTION="--enhance-graphiql"
fi

##############################################################################
#               SHARED DEFAULTS (JWT, DEFAULT ROLE, ETC.)
##############################################################################

DEFAULT_ROLE=${DEFAULT_ROLE:-app_user}
JWT_SECRET=${JWT_SECRET:-SUPER_SECRET_TOKEN}
JWT_TOKEN_IDENTIFIER=${JWT_TOKEN_IDENTIFIER:-public.jwt_token}

##############################################################################
#                    FUNCTION: RUN POSTGRAPHILE
##############################################################################
# We centralize all repeated PostGraphile flags in one function.

runPostgraphile() {
  local connection_string="$1"

  # Just an extra echo to confirm the single-line connection string:
  echo "Final connection string used by PostGraphile: $connection_string"

  npx postgraphile \
    --connection "$connection_string" \
    --schema public \
    --host 0.0.0.0 \
    --port "$PORT" \
    --default-role "$DEFAULT_ROLE" \
    --jwt-secret "$JWT_SECRET" \
    --jwt-token-identifier "$JWT_TOKEN_IDENTIFIER" \
    $GRAPHIQL_OPTION \
    "${POSITIONAL_ARGS[@]}"
}

##############################################################################
#          FUNCTION: BUILD NEON CONNECTION STRING (old run-neon.sh)
##############################################################################
# We replicate your old script *verbatim*, including NEON_USER=auth_user.
# The key difference is we print debug lines to stderr so they don't
# pollute the actual output that goes to stdout.

buildNeonConnectionString() {
  # Replicate old run-neon.sh variable logic:
  local neonUser="${NEON_USER:-auth_user}"
  local neonPass="${NEON_PASSWORD:-}"
  local neonHost="${NEON_HOST:-127.0.0.1}"
  local neonDb="${NEON_DB:-coop-members}"
  local neonSslMode="${SSLMODE:-require}"

  # Old run-neon.sh would do:
  #   echo "Using NEON_USER=$NEON_USER, host=$NEON_HOST, db=$NEON_DB, sslmode=$SSLMODE"
  #   NEON_USER=auth_user
  #
  # We'll replicate that, but as debug to stderr:
  >&2 echo "Using NEON_USER=$neonUser, host=$neonHost, db=$neonDb, sslmode=$neonSslMode"
  >&2 echo "Connecting with default role: $DEFAULT_ROLE"
  >&2 echo "Overriding NEON_USER => auth_user"

  # EXACT override from old run-neon.sh:
  neonUser="auth_user"

  # Return final single-line connection string to stdout:
  echo "postgres://${neonUser}:${neonPass}@${neonHost}:5432/${neonDb}?sslmode=${neonSslMode}"
}

##############################################################################
#         FUNCTION: BUILD LOCAL CONNECTION STRING (old run-local-postgraphile.sh)
##############################################################################

buildLocalConnectionString() {
  local localUser="${LOCAL_USER:-auth_user}"
  local localPass="${LOCAL_PASSWORD:-}"
  local localDb="${LOCAL_DB:-coop-members}"
  local socketPath="${LOCAL_SOCKET_PATH:-/var/run/postgresql}"
  local sslMode="${SSL_MODE:-disable}"

  # Debug messages to stderr
  >&2 echo "Using Unix domain socket at: $socketPath"
  >&2 echo "Connecting as user: $localUser, DB: $localDb, sslmode=$sslMode"
  >&2 echo "Connecting with default role: $DEFAULT_ROLE"

  if [ -n "$localPass" ]; then
    echo "postgres://${localUser}:${localPass}@/${localDb}?host=${socketPath}&sslmode=${sslMode}"
  else
    echo "postgres://${localUser}@/${localDb}?host=${socketPath}&sslmode=${sslMode}"
  fi
}

##############################################################################
#                            MAIN LOGIC
##############################################################################

if [ "$USE_NEON" = "1" ]; then
  echo "Running in NEON mode..."
  neonConn="$(buildNeonConnectionString)"
  runPostgraphile "$neonConn"
else
  echo "Running in LOCAL mode..."
  localConn="$(buildLocalConnectionString)"
  runPostgraphile "$localConn"
fi

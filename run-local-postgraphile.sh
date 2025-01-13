#!/usr/bin/env bash
PORT=${PORT:-5000}
DISABLE_GRAPHIQL=0

# Parse flags
POSITIONAL_ARGS=()
for arg in "$@"; do
  case $arg in
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

echo "Starting PostGraphile locally on port $PORT..."

if [ "$DISABLE_GRAPHIQL" = "1" ]; then
  GRAPHIQL_OPTION="--disable-graphiql"
else
  GRAPHIQL_OPTION="--enhance-graphiql"
fi

# Default values
LOCAL_USER=${LOCAL_USER:-auth_user}
LOCAL_PASSWORD=${LOCAL_PASSWORD:-}  # Often not needed for local socket auth
LOCAL_DB=${LOCAL_DB:-coop-members}
LOCAL_SOCKET_PATH=${LOCAL_SOCKET_PATH:-/var/run/postgresql}
SSL_MODE=${SSL_MODE:-disable}

# We'll default PostGraphile to use "app_user" as its DB role
DEFAULT_ROLE=${DEFAULT_ROLE:-app_user}

# --------------------------------------------------------------------------
# If you're using Unix domain sockets, typically:
#   host=/var/run/postgresql
#   port is not used at all.
#
# The connection string format is:
#   postgres://USER[:PASSWORD]@/DB_NAME?host=SOCKET_PATH&sslmode=SSL_MODE
#
# Note that we omit :PASSWORD if you don't need one locally.
# --------------------------------------------------------------------------

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
  --jwt-secret "SUPER_SECRET_TOKEN" \
  --jwt-token-identifier "public.jwt_token" \
  --default-role "$DEFAULT_ROLE" \
  --host 0.0.0.0 \
  --port "$PORT" \
  $GRAPHIQL_OPTION \
  "${POSITIONAL_ARGS[@]}"

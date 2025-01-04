#!/usr/bin/env bash
set -e  # Exit on error

###############################################################################
# Usage:
#   ./remove-recreate-db.sh neon
#   ./remove-recreate-db.sh
#   (or rely on GITHUB_ACTIONS="true", or local 'postgres' detection)
###############################################################################

MODE="$1"  # could be "neon" or empty
shift || true

DB_NAME="coop-members"
DB_USER="coop-members"

###############################################################################
# Step 1) Pick mode: neon, gha, local, or fail
###############################################################################
if [ "$MODE" = "neon" ]; then
  # Neon-only mode
  : "${NEON_USER:?NEON_USER not set}"
  : "${NEON_PASSWORD:?NEON_PASSWORD not set}"
  : "${NEON_HOST:?NEON_HOST not set}"
  : "${NEON_DB:?NEON_DB not set}"
  : "${SSLMODE:?SSLMODE not set}"

  echo "[Neon-only script] Using NEON_USER='$NEON_USER' on host='$NEON_HOST'"
  echo "DB=$NEON_DB, SSLMODE=$SSLMODE"

  PSQL_USER="$NEON_USER"
  PSQL_PASS="$NEON_PASSWORD"
  PSQL_HOST="$NEON_HOST"
  PSQL_PORT="5432"
  PSQL_DB="postgres"    # Neon typically uses "postgres" for admin tasks
  PSQL_SSLMODE="$SSLMODE"

  MODE="neon"  # keep consistent

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  # GitHub Actions mode
  echo "[CI mode] => GITHUB_ACTIONS=true => host=127.0.0.1:5432, user=postgres."
  PSQL_USER="postgres"
  PSQL_PASS="${DBPASS:-postgres}"
  PSQL_HOST="127.0.0.1"
  PSQL_PORT="5432"
  PSQL_DB="postgres"
  PSQL_SSLMODE=""  # not used in GHA

  MODE="gha"

elif id postgres &>/dev/null; then
  # Local Ubuntu mode
  echo "[Local mode] => OS user 'postgres' is present."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing as 'postgres' user..."
    exec sudo -u postgres bash "$0" "local"
  fi

  # In local mode, we connect via local socket, so no host/port required
  PSQL_USER="postgres"
  PSQL_PASS=""  # no password
  PSQL_HOST=""  # local socket
  PSQL_PORT=""  # local socket
  PSQL_DB="postgres"
  PSQL_SSLMODE=""  # not used

  MODE="local"

else
  # No recognized mode => fail
  echo "ERROR: Not 'neon', not GHA, no local 'postgres' user => can't connect."
  echo "Usage examples:"
  echo "  ./remove-recreate-db.sh neon    # Neon mode (env-based credentials)"
  echo "  ./remove-recreate-db.sh         # GHA or local dev"
  exit 1
fi

###############################################################################
# Step 2) Helper: run_psql (reads global vars set above)
###############################################################################
run_psql() {
  local sql="$1"

  # Build up the psql command flags
  local flags=(-X -A -t -c "$sql")
  [ -n "$PSQL_HOST" ] && flags+=("--host=$PSQL_HOST")
  [ -n "$PSQL_PORT" ] && flags+=("--port=$PSQL_PORT")
  [ -n "$PSQL_USER" ] && flags+=("--username=$PSQL_USER")
  [ -n "$PSQL_SSLMODE" ] && flags+=("--set=sslmode=$PSQL_SSLMODE")

  PGPASSWORD="$PSQL_PASS" psql "${flags[@]}" "$PSQL_DB"
}

###############################################################################
# Step 3) Drop the DB only
###############################################################################
do_drop_db() {
  echo ""
  echo "=== Dropping database '$DB_NAME' (if exists) ==="
  run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"
}

###############################################################################
# Step 4) Local-only: reassign everything from old user to postgres, drop owned
###############################################################################
do_local_reassign() {
  # In local mode, reassign or drop leftover objects in other DBs
  if [ "$MODE" = "local" ]; then
    # Check if the user actually exists before reassigning
    local user_exists
    user_exists="$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")"

    if [ "$user_exists" = "1" ]; then
      echo ""
      echo "=== Reassigning objects owned by '$DB_USER' to 'postgres' ==="
      run_psql "REASSIGN OWNED BY \"$DB_USER\" TO postgres;"

      echo "=== Dropping objects still owned by '$DB_USER' ==="
      run_psql "DROP OWNED BY \"$DB_USER\" CASCADE;"
    else
      echo ""
      echo "=== Skipping reassign; role '$DB_USER' does not exist ==="
    fi
  fi
}

###############################################################################
# Step 5) Drop the user (if exists)
###############################################################################
do_drop_user() {
  echo ""
  echo "=== Dropping user '$DB_USER' (if exists) ==="
  run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"
}

###############################################################################
# Step 6) Create the user (with or without password), create the DB
###############################################################################
do_create_db_user() {
  echo ""
  if [ "$MODE" = "neon" ]; then
    echo "=== Creating user '$DB_USER' with password '$PSQL_PASS' ==="
    run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$PSQL_PASS';"

    echo ""
    echo "=== Creating database '$DB_NAME', as Neon user='$PSQL_USER' ==="
    run_psql "CREATE DATABASE \"$DB_NAME\";"

    echo ""
    echo "=== Granting privileges on database '$DB_NAME' to '$DB_USER' ==="
    run_psql "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

  elif [ "$MODE" = "gha" ]; then
    echo "=== Creating user '$DB_USER' with NO password ==="
    run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

    echo ""
    echo "=== Creating database '$DB_NAME', owned by '$DB_USER' ==="
    run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

  elif [ "$MODE" = "local" ]; then
    echo "=== Creating user '$DB_USER' with NO password ==="
    run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

    echo ""
    echo "=== Creating database '$DB_NAME', owned by '$DB_USER' ==="
    run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
  fi
}

###############################################################################
# Step 7) Verify DB and user exist
###############################################################################
do_verify() {
  echo ""
  echo "=== Verifying user/role '$DB_USER' ==="
  local USER_EXISTS
  USER_EXISTS="$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")"
  if [ "$USER_EXISTS" = "1" ]; then
    echo "  ✓ Role '$DB_USER' exists."
  else
    echo "  ✗ Role '$DB_USER' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Verifying database '$DB_NAME' ==="
  local DB_EXISTS
  DB_EXISTS="$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")"
  if [ "$DB_EXISTS" = "1" ]; then
    echo "  ✓ Database '$DB_NAME' exists."
  else
    echo "  ✗ Database '$DB_NAME' NOT found!"
    exit 1
  fi
}

###############################################################################
# Step 8) Put it all together
###############################################################################
do_drop_db         # 1) Drop DB (if exists)
do_local_reassign  # 2) Local-only: reassign leftover objects (if user exists)
do_drop_user       # 3) Drop the user (if exists)
do_create_db_user  # 4) Create user & DB
do_verify          # 5) Verify user & DB

echo ""
echo "=== Done! '$DB_NAME' is re-created and owned by '$DB_USER'. ==="
case "$MODE" in
  neon)
    echo "    Neon mode => connected via $PSQL_USER@$PSQL_HOST with password."
    ;;
  gha)
    echo "    GHA mode => used host=127.0.0.1:5432, pass in DBPASS, no user pw."
    ;;
  local)
    echo "    Local mode => used local socket, OS 'postgres' user, no user pw."
    ;;
esac

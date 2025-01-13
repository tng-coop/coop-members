#!/usr/bin/env bash
set -e  # Exit on error

###############################################################################
# Usage:
#   ./remove-recreate-db.sh neon
#   ./remove-recreate-db.sh
#   (or rely on GITHUB_ACTIONS="true", or local 'postgres' detection)
#
# Purpose:
#   - Drops & re-creates a database named "coop-members"
#   - Creates two roles:
#       1) auth_user (LOGIN)        => the authenticator role
#       2) app_user  (NOLOGIN)      => the application role
#   - In Neon mode, both roles get a password = NEON_PASSWORD.
#   - Grants minimal privileges to app_user (CONNECT, USAGE)
#   - Grants app_user TO auth_user (so auth_user can SET ROLE app_user)
###############################################################################

MODE="$1"  # could be "neon" or empty
shift || true

DB_NAME="coop-members"
AUTH_ROLE="auth_user"  # Authenticator role (LOGIN)
APP_ROLE="app_user"    # Application role (NOLOGIN)
SHADOW_DB="${DB_NAME}-shadow"  # Optional for local dev

###############################################################################
# Step 1) Pick mode: neon, gha, local, or fail
###############################################################################
if [ "$MODE" = "neon" ]; then
  : "${NEON_USER:?NEON_USER not set}"
  : "${NEON_PASSWORD:?NEON_PASSWORD not set}"
  : "${NEON_HOST:?NEON_HOST not set}"
  : "${NEON_DB:?NEON_DB not set}"
  : "${SSLMODE:?SSLMODE not set}"

  echo "[Neon-only script] Using NEON_USER='$NEON_USER' on host='$NEON_HOST'"
  echo "DB=$NEON_DB, SSLMODE=$SSLMODE"

  # We'll connect as NEON_USER to run admin commands (DROP/CREATE DB, etc.)
  PSQL_USER="$NEON_USER"
  PSQL_PASS="$NEON_PASSWORD"
  PSQL_HOST="$NEON_HOST"
  PSQL_PORT="5432"
  PSQL_DB="postgres"    # Neon typically uses "postgres" as the admin DB
  PSQL_SSLMODE="$SSLMODE"

  MODE="neon"

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  # GitHub Actions mode
  echo "[CI mode] => GITHUB_ACTIONS=true => host=127.0.0.1:5432, user=postgres."
  PSQL_USER="postgres"
  PSQL_PASS="${DBPASS:-postgres}"
  PSQL_HOST="127.0.0.1"
  PSQL_PORT="5432"
  PSQL_DB="postgres"
  PSQL_SSLMODE=""  # Not used in GHA

  MODE="gha"

elif id postgres &>/dev/null; then
  # Local Ubuntu mode
  echo "[Local mode] => OS user 'postgres' is present."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing as 'postgres' user..."
    exec sudo -u postgres bash "$0" "local"
  fi

  PSQL_USER="postgres"
  PSQL_PASS=""
  PSQL_HOST=""
  PSQL_PORT=""
  PSQL_DB="postgres"
  PSQL_SSLMODE=""

  MODE="local"

else
  echo "ERROR: Not 'neon', not GHA, no local 'postgres' user => can't connect."
  echo "Usage examples:"
  echo "  ./remove-recreate-db.sh neon    # Neon mode (env-based credentials)"
  echo "  ./remove-recreate-db.sh         # GHA or local dev"
  exit 1
fi

###############################################################################
# Step 2) Helper function to run psql
###############################################################################
run_psql() {
  local sql="$1"

  local flags=(-X -A -t -c "$sql")
  [ -n "$PSQL_HOST" ] && flags+=("--host=$PSQL_HOST")
  [ -n "$PSQL_PORT" ] && flags+=("--port=$PSQL_PORT")
  [ -n "$PSQL_USER" ] && flags+=("--username=$PSQL_USER")
  [ -n "$PSQL_SSLMODE" ] && flags+=("--set=sslmode=$PSQL_SSLMODE")

  PGPASSWORD="$PSQL_PASS" psql "${flags[@]}" "$PSQL_DB"
}

###############################################################################
# Step 3) Drop the main DB if it exists
###############################################################################
do_drop_db() {
  echo ""
  echo "=== Dropping database '$DB_NAME' (if exists) ==="
  run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"
}

###############################################################################
# Step 4) Drop the shadow DB (local mode only)
###############################################################################
do_drop_shadow_db() {
  if [ "$MODE" = "local" ]; then
    echo ""
    echo "=== Dropping shadow database '$SHADOW_DB' (if exists) ==="
    run_psql "DROP DATABASE IF EXISTS \"$SHADOW_DB\";"
  fi
}

###############################################################################
# Step 5) Local-only: reassign from old roles to postgres, drop owned
###############################################################################
do_local_reassign() {
  if [ "$MODE" = "local" ]; then
    for role in "$AUTH_ROLE" "$APP_ROLE"; do
      local role_exists
      role_exists="$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$role';")"
      if [ "$role_exists" = "1" ]; then
        echo ""
        echo "=== Reassigning objects from '$role' to 'postgres' ==="
        run_psql "REASSIGN OWNED BY \"$role\" TO postgres;"

        echo "=== Dropping objects still owned by '$role' ==="
        run_psql "DROP OWNED BY \"$role\" CASCADE;"
      fi
    done
  fi
}

###############################################################################
# Step 6) Drop the roles (if exist)
###############################################################################
do_drop_roles() {
  echo ""
  echo "=== Dropping roles '$AUTH_ROLE' and '$APP_ROLE' (if exist) ==="
  run_psql "DROP ROLE IF EXISTS \"$AUTH_ROLE\";"
  run_psql "DROP ROLE IF EXISTS \"$APP_ROLE\";"
}

###############################################################################
# Step 7) Create the DB
###############################################################################
do_create_db() {
  echo ""
  echo "=== Creating database '$DB_NAME' ==="
  run_psql "CREATE DATABASE \"$DB_NAME\";"
}

###############################################################################
# Step 8a) Create the app_user role (NOLOGIN)
###############################################################################
do_create_app_user() {
  echo ""
  if [ "$MODE" = "neon" ]; then
    echo "=== Creating NOLOGIN role '$APP_ROLE' with password '$PSQL_PASS' ==="
    run_psql "CREATE ROLE \"$APP_ROLE\" NOLOGIN PASSWORD '$PSQL_PASS';"
  else
    echo "=== Creating NOLOGIN role '$APP_ROLE' (no password) ==="
    run_psql "CREATE ROLE \"$APP_ROLE\" NOLOGIN;"
  fi
}

###############################################################################
# Step 8b) Create the auth_user role (LOGIN)
###############################################################################
do_create_auth_user() {
  echo ""
  if [ "$MODE" = "neon" ]; then
    echo "=== Creating LOGIN role '$AUTH_ROLE' with password '$PSQL_PASS' ==="
    run_psql "CREATE ROLE \"$AUTH_ROLE\" WITH LOGIN PASSWORD '$PSQL_PASS';"
  else
    echo "=== Creating LOGIN role '$AUTH_ROLE' (no password) ==="
    run_psql "CREATE ROLE \"$AUTH_ROLE\" WITH LOGIN;"
  fi
}

###############################################################################
# Step 9) Grant minimal privileges to app_user
###############################################################################
do_grant_min_privs_to_app_user() {
  echo ""
  echo "=== Granting minimal privileges to '$APP_ROLE' on DB='$DB_NAME' ==="
  local old_db="$PSQL_DB"
  PSQL_DB="$DB_NAME"

  # Revoke all privileges just to be safe
  run_psql "REVOKE ALL PRIVILEGES ON DATABASE \"$DB_NAME\" FROM \"$APP_ROLE\";"
  
  # 1) Let app_user CONNECT to the DB
  run_psql "GRANT CONNECT ON DATABASE \"$DB_NAME\" TO \"$APP_ROLE\";"

  # 2) Let app_user use the schema for introspection, etc.
  run_psql "GRANT USAGE ON SCHEMA public TO \"$APP_ROLE\";"

  # Optional: If you want SELECT/INSERT/UPDATE on all tables, you could do:
  # run_psql "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"$APP_ROLE\";"

  PSQL_DB="$old_db"
}

###############################################################################
# Step 10) Grant app_user TO auth_user (so auth_user can SET ROLE app_user)
###############################################################################
do_grant_appuser_to_authuser() {
  echo ""
  echo "=== Granting '$APP_ROLE' to '$AUTH_ROLE' ==="
  run_psql "GRANT \"$APP_ROLE\" TO \"$AUTH_ROLE\";"
}

###############################################################################
# Step 11) Create shadow DB (local only)
###############################################################################
do_create_shadow_db() {
  if [ "$MODE" = "local" ]; then
    echo ""
    echo "=== Creating shadow database '$SHADOW_DB' owned by '$AUTH_ROLE' ==="
    run_psql "CREATE DATABASE \"$SHADOW_DB\" OWNER \"$AUTH_ROLE\";"
  fi
}

###############################################################################
# Step 12) Verify DB and roles exist
###############################################################################
do_verify() {
  echo ""
  for role in "$AUTH_ROLE" "$APP_ROLE"; do
    echo "=== Verifying role '$role' ==="
    local role_exists
    role_exists="$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$role';")"
    if [ "$role_exists" = "1" ]; then
      echo "  ✓ Role '$role' exists."
    else
      echo "  ✗ Role '$role' NOT found!"
      exit 1
    fi
  done

  echo ""
  echo "=== Verifying database '$DB_NAME' ==="
  local db_exists
  db_exists="$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")"
  if [ "$db_exists" = "1" ]; then
    echo "  ✓ Database '$DB_NAME' exists."
  else
    echo "  ✗ Database '$DB_NAME' NOT found!"
    exit 1
  fi
}

###############################################################################
# Step 13) Put it all together
###############################################################################
do_drop_db
do_drop_shadow_db
do_local_reassign
do_drop_roles
do_create_db
do_create_app_user
do_create_auth_user
do_grant_min_privs_to_app_user
do_grant_appuser_to_authuser
do_verify
do_create_shadow_db

echo ""
echo "=== Done! '$DB_NAME' is re-created. Roles '$AUTH_ROLE' (LOGIN) & '$APP_ROLE' (NOLOGIN) created. ==="

case "$MODE" in
  neon)
    echo "    Neon mode => connected via $PSQL_USER@$PSQL_HOST with password=$PSQL_PASS."
    echo "    Both roles have password='$PSQL_PASS' (though app_user is NOLOGIN)."
    ;;
  gha)
    echo "    GHA mode => used host=127.0.0.1:5432, pass in DBPASS, no user pw."
    ;;
  local)
    echo "    Local mode => used local socket, OS 'postgres' user, no user pw."
    echo "    Shadow DB '$SHADOW_DB' created for local dev."
    ;;
esac

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
#   - Creates three roles (for local/GHA):
#       1) migrator (LOGIN, CREATEDB) => for running migrations
#       2) auth_user (LOGIN)         => the authenticator role
#       3) app_user  (NOLOGIN)       => the application role
#   - In Neon mode, we skip the migrator approach (Neon won't allow it).
#   - Grants minimal privileges to app_user (CONNECT, USAGE)
#   - Grants app_user TO auth_user (so auth_user can SET ROLE app_user)
###############################################################################

MODE="$1"  # could be "neon", "gha", "local", or empty
shift || true

DB_NAME="coop-members"
MIGRATOR_ROLE="migrator"
AUTH_ROLE="auth_user"
APP_ROLE="app_user"
SHADOW_DB="${DB_NAME}-shadow"  # Optional for local dev

###############################################################################
# Step 1) Determine environment mode
###############################################################################
if [ "$MODE" = "neon" ]; then
  : "${NEON_USER:?NEON_USER not set}"
  : "${NEON_PASSWORD:?NEON_PASSWORD not set}"
  : "${NEON_HOST:?NEON_HOST not set}"
  : "${NEON_DB:?NEON_DB not set}"
  : "${SSLMODE:?SSLMODE not set}"

  echo "[Neon-only script] Using NEON_USER='$NEON_USER' on host='$NEON_HOST'"
  echo "DB=$NEON_DB, SSLMODE=$SSLMODE"

  # We'll connect as NEON_USER to run admin commands
  PSQL_USER="$NEON_USER"
  PSQL_PASS="$NEON_PASSWORD"
  PSQL_HOST="$NEON_HOST"
  PSQL_PORT="5432"
  # Neon typically uses "postgres" as the "admin DB" for mgmt commands
  PSQL_DB="postgres"
  PSQL_SSLMODE="$SSLMODE"

  MODE="neon"

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[CI mode] => GITHUB_ACTIONS=true => host=127.0.0.1:5432, user=postgres."
  PSQL_USER="postgres"
  PSQL_PASS="${DBPASS:-postgres}"
  PSQL_HOST="127.0.0.1"
  PSQL_PORT="5432"
  PSQL_DB="postgres"
  PSQL_SSLMODE=""
  MODE="gha"

elif id postgres &>/dev/null; then
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
    for role in "$MIGRATOR_ROLE" "$AUTH_ROLE" "$APP_ROLE"; do
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
  echo "=== Dropping roles '$MIGRATOR_ROLE', '$AUTH_ROLE', and '$APP_ROLE' (if exist) ==="
  run_psql "DROP ROLE IF EXISTS \"$MIGRATOR_ROLE\";"
  run_psql "DROP ROLE IF EXISTS \"$AUTH_ROLE\";"
  run_psql "DROP ROLE IF EXISTS \"$APP_ROLE\";"
}

###############################################################################
# Step 7) Create MIGRATOR role or skip for Neon
###############################################################################
do_create_migrator_role_local() {
  echo "=== Creating LOGIN role '$MIGRATOR_ROLE' with CREATEDB ==="
  run_psql "CREATE ROLE \"$MIGRATOR_ROLE\" WITH LOGIN CREATEDB;"
}

do_create_migrator_role_neon() {
  echo "=== Neon mode: skipping MIGRATOR role with CREATEDB. ==="
}

###############################################################################
# Step 8) Create DB
###############################################################################
do_create_db_owned_by_migrator() {
  echo ""
  echo "=== Creating database '$DB_NAME' owned by '$MIGRATOR_ROLE' ==="
  run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$MIGRATOR_ROLE\";"
}

do_create_db_owned_by_neon_admin() {
  # For Neon, create DB under the current NEON_USER
  echo "=== Creating database '$DB_NAME' (owned by $NEON_USER) ==="
  run_psql "CREATE DATABASE \"$DB_NAME\";"
}

###############################################################################
# Step 9) Create app_user role (NOLOGIN)
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
# Step 10) Create auth_user role (LOGIN)
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
# Step 11) Grant minimal privileges to app_user
###############################################################################
do_grant_min_privs_to_app_user() {
  echo ""
  echo "=== Granting minimal privileges to '$APP_ROLE' on DB='$DB_NAME' ==="
  local old_db="$PSQL_DB"
  PSQL_DB="$DB_NAME"

  run_psql "REVOKE ALL PRIVILEGES ON DATABASE \"$DB_NAME\" FROM \"$APP_ROLE\";"
  run_psql "GRANT CONNECT ON DATABASE \"$DB_NAME\" TO \"$APP_ROLE\";"
  run_psql "GRANT USAGE ON SCHEMA public TO \"$APP_ROLE\";"

  PSQL_DB="$old_db"
}

###############################################################################
# Step 12) Grant app_user TO auth_user (so auth_user can SET ROLE app_user)
###############################################################################
do_grant_appuser_to_authuser() {
  echo ""
  echo "=== Granting '$APP_ROLE' to '$AUTH_ROLE' ==="
  run_psql "GRANT \"$APP_ROLE\" TO \"$AUTH_ROLE\";"
}

###############################################################################
# Step 13) Create shadow DB (local only)
###############################################################################
do_create_shadow_db() {
  if [ "$MODE" = "local" ]; then
    echo ""
    echo "=== Creating shadow database '$SHADOW_DB' owned by '$MIGRATOR_ROLE' ==="
    run_psql "CREATE DATABASE \"$SHADOW_DB\" OWNER \"$MIGRATOR_ROLE\";"
  fi
}

###############################################################################
# Step 14) Verify DB and roles exist
###############################################################################
do_verify() {
  echo ""

  # In Neon mode, we skip 'migrator' because we didn't create it.
  local roles_to_check=("$AUTH_ROLE" "$APP_ROLE")
  if [ "$MODE" != "neon" ]; then
    roles_to_check+=("$MIGRATOR_ROLE")
  fi

  for role in "${roles_to_check[@]}"; do
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
# Step 15) Put it all together
###############################################################################

# (A) Drop DB(s)
do_drop_db
do_drop_shadow_db

# (B) Local reassign + drop roles
do_local_reassign
do_drop_roles

# (C) Create roles/DB depending on mode
if [ "$MODE" = "neon" ]; then
  # Neon => skip 'migrator' approach
  do_create_migrator_role_neon
  do_create_db_owned_by_neon_admin
else
  # local/gha => do migrator approach
  do_create_migrator_role_local
  do_create_db_owned_by_migrator
fi

# (D) Create app/auth roles, set privileges
do_create_app_user
do_create_auth_user
do_grant_min_privs_to_app_user
do_grant_appuser_to_authuser

# (E) Verify
do_verify

# (F) Local shadow DB
do_create_shadow_db

echo ""
echo "=== Done! '$DB_NAME' is re-created. Roles:"
if [ "$MODE" = "neon" ]; then
  echo "    (skipping 'migrator' role, Neon admin owns the DB)"
else
  echo "    - '$MIGRATOR_ROLE' (LOGIN, CREATEDB) => for migrations"
fi
echo "    - '$AUTH_ROLE' (LOGIN)               => authenticator"
echo "    - '$APP_ROLE' (NOLOGIN)              => actual app privileges"
[ "$MODE" = "local" ] && echo "Shadow DB '$SHADOW_DB' created for local dev."
echo ""

case "$MODE" in
  neon)
    echo "Neon mode => connected via $PSQL_USER@$PSQL_HOST with password=$PSQL_PASS."
    echo "All LOGIN roles have password='$PSQL_PASS'."
    ;;
  gha)
    echo "GHA mode => used host=127.0.0.1:5432, pass in DBPASS, no user pw."
    ;;
  local)
    echo "Local mode => used local socket, OS 'postgres' user, no user pw."
    echo "Shadow DB '$SHADOW_DB' created for local dev."
    ;;
esac

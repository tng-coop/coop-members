#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# One script that works both locally (with OS user 'postgres') and in CI
# (where 'postgres' OS user doesn't exist, so it uses TCP + password).
#
# The difference from before: the verification steps use `psql -X -A -t`
# to reliably parse output lines.

set -e  # Exit on error

###############################################################################
# 1) Detect if OS user 'postgres' exists
###############################################################################
if id postgres &>/dev/null; then
  # ---------------------------
  # LOCAL MODE (Ubuntu, etc.)
  # ---------------------------
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "[Local mode] Re-executing script as OS user 'postgres'..."
    exec sudo -u postgres bash "$0" "$@"
    # 'exec' replaces the current process
  fi

  # Now we are running as the OS user 'postgres'
  function run_psql() {
    psql -X -A -t -c "$1"
  }
else
  # ---------------------------
  # CI MODE (GitHub Actions, etc.)
  # ---------------------------
  echo "[CI mode] No OS user 'postgres' found. Assuming Docker-based Postgres on 127.0.0.1:5432..."

  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="postgres"

  function run_psql() {
    PGPASSWORD="$DBPASS" psql -X -A -t -h "$DBHOST" -p "$DBPORT" -U "$DBUSER" -c "$1"
  }
fi

###############################################################################
# 2) Database + User config
###############################################################################
DB_NAME="open-members"
DB_USER="coop-members"

###############################################################################
# 3) Drop the DB (if exists)
###############################################################################
echo "=== Dropping database '$DB_NAME' (if exists) ==="
run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

###############################################################################
# 4) Drop the user (if exists)
###############################################################################
echo ""
echo "=== Dropping user '$DB_USER' (if exists) ==="
run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

###############################################################################
# 5) Re-create the user with NO password
###############################################################################
echo ""
echo "=== Creating user '$DB_USER' with NO password ==="
run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

###############################################################################
# 6) Create the DB, owned by that user
###############################################################################
echo ""
echo "=== Creating database '$DB_NAME' owned by '$DB_USER' ==="
run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

###############################################################################
# 7) Verification
###############################################################################
echo ""
echo "=== Verifying user and database exist ==="

echo "- Checking user '$DB_USER' in pg_roles..."
USER_EXISTS=$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")
if [ "$USER_EXISTS" = "1" ]; then
  echo "  ✓ User '$DB_USER' exists."
else
  echo "  ✗ User '$DB_USER' NOT found!"
  exit 1
fi

echo "- Checking database '$DB_NAME' in pg_database..."
DB_EXISTS=$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")
if [ "$DB_EXISTS" = "1" ]; then
  echo "  ✓ Database '$DB_NAME' exists."
else
  echo "  ✗ Database '$DB_NAME' NOT found!"
  exit 1
fi

###############################################################################
# Done
###############################################################################
echo ""
echo "=== Done! '$DB_NAME' is ready, owned by user '$DB_USER' (NO password). ==="
echo "=== Local or CI environment auto-detected. No manual toggles needed. ==="

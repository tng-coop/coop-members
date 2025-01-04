#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# A single script that:
#   - In GitHub Actions (GITHUB_ACTIONS=true), uses TCP w/ user=postgres, pass=postgres.
#   - Otherwise, if local OS user 'postgres' exists, re-runs itself via sudo (local-socket).
#   - Verification uses psql -X -A -t to parse output cleanly.

set -e

###############################################################################
# Step 1) Detect GitHub Actions vs. Local OS
###############################################################################
if [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[CI mode] Detected GITHUB_ACTIONS=true. Using TCP on 127.0.0.1:5432 with user=postgres, pass=postgres."
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="postgres"

  function run_psql() {
    PGPASSWORD="$DBPASS" psql -X -A -t -h "$DBHOST" -p "$DBPORT" -U "$DBUSER" -c "$1"
  }

elif id postgres &>/dev/null; then
  echo "[Local mode] Found OS user 'postgres'."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing script as OS user 'postgres'..."
    exec sudo -u postgres bash "$0" "$@"
  fi

  function run_psql() {
    # Local socket, running as OS user 'postgres'
    psql -X -A -t -c "$1"
  }
else
  echo "ERROR: Not in GitHub Actions, and no 'postgres' OS user found. Not sure how to connect."
  echo "Please install Postgres or create a 'postgres' user, or set GITHUB_ACTIONS=true in CI."
  exit 1
fi

###############################################################################
# Step 2) Database + User config
###############################################################################
DB_NAME="open-members"
DB_USER="coop-members"

###############################################################################
# Step 3) Drop the DB (if exists)
###############################################################################
echo "=== Dropping database '$DB_NAME' (if exists) ==="
run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

###############################################################################
# Step 4) Drop the user (if exists)
###############################################################################
echo ""
echo "=== Dropping user '$DB_USER' (if exists) ==="
run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

###############################################################################
# Step 5) Recreate the user with NO password
###############################################################################
echo ""
echo "=== Creating user '$DB_USER' with NO password ==="
run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

###############################################################################
# Step 6) Create the DB, owned by that user
###############################################################################
echo ""
echo "=== Creating database '$DB_NAME' owned by '$DB_USER' ==="
run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

###############################################################################
# Step 7) Verification
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
echo "===   • GitHub Actions => used TCP with pass=postgres                   ==="
echo "===   • Local w/ OS 'postgres' => used local socket, no password        ==="

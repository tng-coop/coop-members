#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# A script that:
#   1) Automatically re-runs itself as the 'postgres' OS user (if needed).
#   2) Drops the DB 'open-members' (if it exists).
#   3) Drops the user 'coop-members' (if it exists).
#   4) Recreates the user 'coop-members' WITHOUT a password.
#   5) Creates 'open-members' owned by 'coop-members'.
#   6) Verifies both the user and database exist in Postgres.
#
# Usage:
#   ./remove-recreate-db.sh
#   (No need for "sudo -u postgres" manually; the script handles it.)

set -e  # Exit on error

###############################################################################
# 0) If not running as 'postgres', re-exec ourselves under that user
###############################################################################
CURRENT_USER="$(id -un)"
if [ "$CURRENT_USER" != "postgres" ]; then
  echo "Not running as 'postgres' user. Re-executing with sudo..."
  exec sudo -u postgres bash "$0" "$@"
  # 'exec' replaces the current shell with the new process; no more code here runs.
fi

###############################################################################
# 1) Configuration
###############################################################################
DB_NAME="open-members"
DB_USER="coop-members"

###############################################################################
# 2) Drop the database (if exists)
###############################################################################
echo "=== Dropping database '$DB_NAME' (if exists) ==="
psql -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

###############################################################################
# 3) Drop the user (if exists)
###############################################################################
echo ""
echo "=== Dropping user '$DB_USER' (if exists) ==="
psql -c "DROP ROLE IF EXISTS \"$DB_USER\";"

###############################################################################
# 4) Recreate the user with NO password
###############################################################################
echo ""
echo "=== Creating user '$DB_USER' with NO password ==="
psql -c "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

###############################################################################
# 5) Create the database, owned by that user
###############################################################################
echo ""
echo "=== Creating database '$DB_NAME' owned by '$DB_USER' ==="
psql -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

###############################################################################
# 6) Verification Step
###############################################################################
echo ""
echo "=== Verifying user and database exist ==="

echo "- Checking user '$DB_USER' in pg_roles..."
USER_EXISTS=$(psql -X -A -t -c "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")
if [ "$USER_EXISTS" = "1" ]; then
  echo "  ✓ User '$DB_USER' exists."
else
  echo "  ✗ User '$DB_USER' NOT found!"
  exit 1
fi

echo "- Checking database '$DB_NAME' in pg_database..."
DB_EXISTS=$(psql -X -A -t -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")
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
echo "=== Local peer/trust auth is assumed for connections. ==="

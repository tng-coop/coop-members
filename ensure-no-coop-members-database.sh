#!/usr/bin/env bash
#
# ensure-no-coop-members-database.sh
#
# A script to ensure the database "coop-members" does NOT exist.
# It detects whether to connect via:
#   1) Neon mode (if arg == "neon")
#   2) GitHub Actions (if GITHUB_ACTIONS="true")
#   3) Local (if OS user 'postgres' exists, no neon arg, no GHA)

set -e  # Exit on error

###############################################################################
# 1) Parse args
###############################################################################
MODE="$1"   # Could be "neon" or empty
shift || true  # If there's an arg, shift it

###############################################################################
# 2) Decide which mode to use
###############################################################################
if [ "$MODE" = "neon" ]; then
  echo "[Neon mode] => Using env NEON_USER, NEON_PASSWORD, NEON_HOST, SSLMODE, etc."

  # Make sure essential env vars are present
  if [ -z "$NEON_USER" ] || [ -z "$NEON_PASSWORD" ] || [ -z "$NEON_HOST" ]; then
    echo "ERROR: NEON_USER, NEON_PASSWORD, NEON_HOST must be set for Neon mode."
    exit 1
  fi

  # Default SSL mode if not set
  : "${SSLMODE:=require}"

  function run_psql() {
    PGPASSWORD="$NEON_PASSWORD" psql \
      --host="$NEON_HOST" \
      --port=5432 \
      --username="$NEON_USER" \
      --dbname="postgres" \
      --set=sslmode="$SSLMODE" \
      -c "$1"
  }

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[GitHub Actions mode] => host=127.0.0.1:5432, user=postgres"
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="${DBPASS:-postgres}"  # Default to "postgres" if not set

  function run_psql() {
    PGPASSWORD="$DBPASS" psql \
      --host="$DBHOST" \
      --port="$DBPORT" \
      --username="$DBUSER" \
      --dbname="postgres" \
      -c "$1"
  }

elif id postgres &>/dev/null; then
  echo "[Local mode] => Found OS user 'postgres'."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing script as OS user 'postgres'..."
    exec sudo -u postgres bash "$0"
    # 'exec' replaces current process with the new one
  fi

  function run_psql() {
    psql --dbname="postgres" -c "$1"
  }

else
  echo "ERROR: Not 'neon', not GHA, and no local 'postgres' user => can't connect."
  echo "Usage examples:"
  echo "  ./ensure-no-coop-members-database.sh neon"
  echo "  ./ensure-no-coop-members-database.sh         # (for GHA or local if OS 'postgres')"
  exit 1
fi

###############################################################################
# 3) Drop the DB if it exists
###############################################################################
DB_NAME="coop-members"

echo ""
echo "=== Dropping database '$DB_NAME' (if exists) ==="
run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

echo ""
echo "=== Done! The '$DB_NAME' DB no longer exists (if you had permission). ==="

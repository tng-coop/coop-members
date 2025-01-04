#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# A single script with three modes:
#
# 1) Neon mode:  ./remove-recreate-db.sh neon
#    - Uses environment-based credentials (NEON_USER, NEON_PASSWORD, NEON_HOST, NEON_DB, SSLMODE)
#    - Creates DB named "coop-members" and user "coop-members" WITH a password (Neon requirement)
#
# 2) GitHub Actions mode (GITHUB_ACTIONS="true"):
#    - Connects to 127.0.0.1:5432 with user=postgres, pass=$DBPASS or "postgres"
#    - Creates "coop-members" with NO password
#    - Creates DB named "coop-members"
#
# 3) Local Ubuntu (if OS user "postgres" exists and you didn't specify "neon"):
#    - Re-exec via sudo -u postgres to use local socket
#    - Creates user "coop-members" with NO password
#    - Creates DB named "coop-members"
#
# Then it:
#  - Neon mode => drops & re-creates "coop-members" DB/user
#  - Local & GHA => drops & re-creates "coop-members" DB and "coop-members" user
#  - Verifies both the DB and user exist
#
# WARNING:
#   - In Neon mode, this script uses environment variables for credentials.
#   - For local/CI modes, the DB is not password-protected unless explicitly set.
#   - In real production, consider using a secrets manager or more secure approach.

set -e  # Exit on error

###############################################################################
# Step 1) Decide if "neon" or not
###############################################################################
MODE="$1"  # could be "neon" or empty
shift || true  # shift the argument away, so $@ is left if any extra

###############################################################################
# Step 2) Connection logic
###############################################################################
if [ "$MODE" = "neon" ]; then
  ###########################################################################
  # NEON-ONLY MODE
  ###########################################################################
  : "${NEON_USER:?NEON_USER not set}"
  : "${NEON_PASSWORD:?NEON_PASSWORD not set}"
  : "${NEON_HOST:?NEON_HOST not set}"
  : "${NEON_DB:?NEON_DB not set}"
  : "${SSLMODE:?SSLMODE not set}"

  echo "[Neon-only script] Using NEON_USER='$NEON_USER' on host='$NEON_HOST'"
  echo "DB=$NEON_DB, SSLMODE=$SSLMODE"

  DB_NAME="coop-members"
  DB_USER="coop-members"

  function run_psql() {
    local sql="$1"
    PGPASSWORD="$NEON_PASSWORD" \
      psql \
        -X -A -t \
        --host="$NEON_HOST" \
        --port=5432 \
        --username="$NEON_USER" \
        --dbname="postgres" \
        --set=sslmode="$SSLMODE" \
        -c "$sql"
  }

  echo ""
  echo "=== Dropping database '$DB_NAME' (if exists) ==="
  run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

  # If you suspect other leftover objects that user might own, you could also do:
  # run_psql "REASSIGN OWNED BY \"$DB_USER\" TO \"$NEON_USER\";"
  # run_psql "DROP OWNED BY \"$DB_USER\" CASCADE;"

  echo ""
  echo "=== Dropping user '$DB_USER' (if exists) ==="
  run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

  echo ""
  echo "=== Creating user '$DB_USER' with password '$NEON_PASSWORD' ==="
  run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$NEON_PASSWORD';"

  echo ""
  echo "=== Creating database '$DB_NAME' as NEON_USER='$NEON_USER' ==="
  run_psql "CREATE DATABASE \"$DB_NAME\";"

  echo ""
  echo "=== Granting privileges on database '$DB_NAME' to '$DB_USER' ==="
  run_psql "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

  echo ""
  echo "=== Verifying role '$DB_USER' ==="
  USER_EXISTS=$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")
  if [ "$USER_EXISTS" = "1" ]; then
    echo "  ✓ Role '$DB_USER' exists."
  else
    echo "  ✗ Role '$DB_USER' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Verifying database '$DB_NAME' ==="
  DB_EXISTS=$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")
  if [ "$DB_EXISTS" = "1" ]; then
    echo "  ✓ Database '$DB_NAME' exists."
  else
    echo "  ✗ Database '$DB_NAME' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Done! '$DB_NAME' is re-created by '$NEON_USER'. ==="
  echo "=== '$DB_USER' can now connect and perform operations. ==="
  echo "    Connected with $NEON_USER@$NEON_HOST (Neon)."
  echo "    New user password = '$NEON_PASSWORD' (sample)."

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  ###########################################################################
  # GITHUB ACTIONS MODE
  ###########################################################################
  echo "[CI mode] => GITHUB_ACTIONS=true => 127.0.0.1:5432, user=postgres."
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="${DBPASS:-postgres}"

  function run_psql() {
    local sql="$1"
    PGPASSWORD="$DBPASS" psql -X -A -t -h "$DBHOST" -p "$DBPORT" -U "$DBUSER" -c "$sql"
  }

  DB_NAME="coop-members"
  DB_USER="coop-members"

  echo ""
  echo "=== Dropping database '$DB_NAME' (if exists) ==="
  run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

  # Similarly, if the user owned other objects, you could reassign or drop them here:
  # run_psql "REASSIGN OWNED BY \"$DB_USER\" TO postgres;"
  # run_psql "DROP OWNED BY \"$DB_USER\" CASCADE;"

  echo ""
  echo "=== Dropping user '$DB_USER' (if exists) ==="
  run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

  echo ""
  echo "=== Creating user '$DB_USER' with NO password ==="
  run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

  echo ""
  echo "=== Creating database '$DB_NAME', owned by '$DB_USER' ==="
  run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

  echo ""
  echo "=== Verifying user '$DB_USER' ==="
  USER_EXISTS=$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")
  if [ "$USER_EXISTS" = "1" ]; then
    echo "  ✓ User '$DB_USER' exists."
  else
    echo "  ✗ User '$DB_USER' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Verifying database '$DB_NAME' ==="
  DB_EXISTS=$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")
  if [ "$DB_EXISTS" = "1" ]; then
    echo "  ✓ Database '$DB_NAME' exists."
  else
    echo "  ✗ Database '$DB_NAME' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Done! '$DB_NAME' is ready, owned by '$DB_USER'. ==="
  echo "   GitHub Actions => used host=127.0.0.1:5432, pass in DBPASS, no user pw"

elif id postgres &>/dev/null; then
  ###########################################################################
  # LOCAL UBUNTU MODE (with bugfix #2)
  ###########################################################################
  echo "[Local mode] => OS user 'postgres' is present."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing as 'postgres' user..."
    exec sudo -u postgres bash "$0" "local"
  fi

  function run_psql() {
    local sql="$1"
    psql -X -A -t -c "$sql"
  }

  DB_NAME="coop-members"
  DB_USER="coop-members"

  echo ""
  echo "=== Dropping database '$DB_NAME' (if exists) ==="
  run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

  #
  # BUGFIX OPTION #2: Reassign or drop *all* objects the user still owns
  #
  # For example, if 'coop-members' owns some other DB "open-members", you could:
  #
  #   run_psql "DROP DATABASE IF EXISTS \"open-members\";"
  #
  # Then reassign ownership of everything else (or drop them) to ensure
  # 'DROP ROLE' does not fail:
  #
  echo ""
  echo "=== Reassigning objects owned by '$DB_USER' to 'postgres' ==="
  run_psql "REASSIGN OWNED BY \"$DB_USER\" TO postgres;"
  echo "=== Dropping objects still owned by '$DB_USER' ==="
  run_psql "DROP OWNED BY \"$DB_USER\" CASCADE;"

  echo ""
  echo "=== Dropping user '$DB_USER' (if exists) ==="
  run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

  echo ""
  echo "=== Creating user '$DB_USER' with NO password ==="
  run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"

  echo ""
  echo "=== Creating database '$DB_NAME', owned by '$DB_USER' ==="
  run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

  echo ""
  echo "=== Verifying user '$DB_USER' ==="
  USER_EXISTS=$(run_psql "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER';")
  if [ "$USER_EXISTS" = "1" ]; then
    echo "  ✓ User '$DB_USER' exists."
  else
    echo "  ✗ User '$DB_USER' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Verifying database '$DB_NAME' ==="
  DB_EXISTS=$(run_psql "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';")
  if [ "$DB_EXISTS" = "1" ]; then
    echo "  ✓ Database '$DB_NAME' exists."
  else
    echo "  ✗ Database '$DB_NAME' NOT found!"
    exit 1
  fi

  echo ""
  echo "=== Done! '$DB_NAME' is ready, owned by '$DB_USER'. ==="
  echo "   Local => OS 'postgres' user, local socket, no user pw"

else
  ###########################################################################
  # No recognized mode
  ###########################################################################
  echo "ERROR: Not 'neon', not GHA, no local 'postgres' user => can't connect."
  echo "Usage examples:"
  echo "  ./remove-recreate-db.sh neon    # Neon mode (env-based credentials)"
  echo "  ./remove-recreate-db.sh         # GHA or local dev"
  exit 1
fi

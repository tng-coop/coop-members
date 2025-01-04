#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# A single script with three modes:
#
# 1) Neon mode:  ./remove-recreate-db.sh neon
#    - Hard-coded credentials for Neon below
#    - Because Neon does NOT allow creating a user with no password, we
#      create "coop-members" with a password (hard-coded).
#
# 2) GitHub Actions mode (GITHUB_ACTIONS="true"):
#    - Connects to 127.0.0.1:5432 with user=postgres, pass=$DBPASS or "postgres"
#    - Creates "coop-members" with NO password
#
# 3) Local Ubuntu (if OS user "postgres" exists and you didn't specify "neon"):
#    - Re-exec via sudo -u postgres to use local socket
#    - Creates "coop-members" with NO password
#
# Then it:
#  - Drops "open-members" DB
#  - Drops "coop-members" user
#  - Creates user "coop-members"
#  - Creates DB "open-members" owned by "coop-members"
#  - Verifies both exist
#
# WARNING: This script hard-codes a Neon password. That is insecure in production.
# Use environment variables or a secrets manager for real deployments!

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
  echo "[Neon mode] No exports needed. Using hard-coded credentials..."

  # ---------------------------------------------------------------------------
  # HARDCODED NEON CREDENTIALS
  # (Replace with your real Neon credentials)
  # ---------------------------------------------------------------------------
  NEON_USER="coop-members_owner"
  NEON_PASSWORD="1sWAdTcp9XKx"
  NEON_HOST="ep-purple-night-a57bomy5.us-east-2.aws.neon.tech"
  NEON_DB="coop-members"
  SSLMODE="require"

  echo "  NEON_USER=$NEON_USER"
  echo "  NEON_HOST=$NEON_HOST"
  echo "  NEON_DB=$NEON_DB"
  echo "  SSLMODE=$SSLMODE"
  
  # Neon requires a password for newly created roles
  CREATE_WITH_PASSWORD="true"
  
  function run_psql() {
    local sql="$1"
    PGPASSWORD="$NEON_PASSWORD" psql -X -A -t \
      --host="$NEON_HOST" \
      --port="5432" \
      --username="$NEON_USER" \
      --dbname="postgres" \
      --set=sslmode="$SSLMODE" \
      -c "$sql"
  }

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[CI mode] => GITHUB_ACTIONS=true => 127.0.0.1:5432, user=postgres."
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="${DBPASS:-postgres}"  # if GH doesn't define DBPASS, default "postgres"

  CREATE_WITH_PASSWORD="false"
  
  function run_psql() {
    local sql="$1"
    PGPASSWORD="$DBPASS" psql -X -A -t -h "$DBHOST" -p "$DBPORT" -U "$DBUSER" -c "$sql"
  }

elif id postgres &>/dev/null; then
  echo "[Local mode] => OS user 'postgres' is present."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing as 'postgres' user..."
    exec sudo -u postgres bash "$0" "local"
    # 'exec' replaces the shell with the new process
  fi

  CREATE_WITH_PASSWORD="false"

  function run_psql() {
    local sql="$1"
    psql -X -A -t -c "$sql"
  }

else
  echo "ERROR: Not 'neon', not GHA, no local 'postgres' user => can't connect."
  echo "Usage examples:"
  echo "  ./remove-recreate-db.sh neon    # Hard-coded Neon credentials"
  echo "  ./remove-recreate-db.sh         # GHA or local dev"
  exit 1
fi

###############################################################################
# Step 3) Database + user we want to create
###############################################################################
DB_NAME="open-members"
DB_USER="coop-members"

# If Neon, define a password for "coop-members" since Neon requires it.
DB_USER_PASSWORD="temp1234"  # <-- Hard-coded example password for "coop-members"

###############################################################################
# Step 4) Drop DB if exists
###############################################################################
echo ""
echo "=== Dropping database '$DB_NAME' (if exists) ==="
run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

###############################################################################
# Step 5) Drop user if exists
###############################################################################
echo ""
echo "=== Dropping user '$DB_USER' (if exists) ==="
run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

###############################################################################
# Step 6) Create user (with or without password)
###############################################################################
if [ "$CREATE_WITH_PASSWORD" = "true" ]; then
  echo ""
  echo "=== Creating user '$DB_USER' WITH password (Neon requires it) ==="
  run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$DB_USER_PASSWORD';"
else
  echo ""
  echo "=== Creating user '$DB_USER' with NO password ==="
  run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN;"
fi

###############################################################################
# Step 7) Create DB, owned by that user
###############################################################################
echo ""
echo "=== Creating database '$DB_NAME', owned by '$DB_USER' ==="
run_psql "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

###############################################################################
# Step 8) Verification
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
echo "=== Done! '$DB_NAME' is ready, owned by '$DB_USER'. ==="

if [ "$MODE" = "neon" ]; then
  echo "   Neon mode => used $NEON_USER@$NEON_HOST, user pw = '$DB_USER_PASSWORD'"
elif [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "   GitHub Actions => used host=127.0.0.1:5432, pass in DBPASS, no user pw"
else
  echo "   Local => OS 'postgres' user, local socket, no user pw"
fi

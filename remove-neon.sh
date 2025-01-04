#!/usr/bin/env bash
#
# remove-recreate-db-neon.sh
#
# Neon-only version: Drops and re-creates one database named "coop-members"
# plus the "coop-members" user (with password).
#
# Prerequisite:
#   - Environment variables: NEON_USER, NEON_PASSWORD, NEON_HOST, NEON_DB, SSLMODE
#   - NEON_USER must be able to create/drop DBs and roles (usually an "_owner" role).
#
# WARNING: For simplicity, we set the new user's password to $NEON_PASSWORD.
#          In real deployments, you should use a separate, securely stored password.

set -e  # Exit on any error

###############################################################################
# 1) Verify required ENV vars
###############################################################################
: "${NEON_USER:?NEON_USER not set}"
: "${NEON_PASSWORD:?NEON_PASSWORD not set}"
: "${NEON_HOST:?NEON_HOST not set}"
: "${NEON_DB:?NEON_DB not set}"
: "${SSLMODE:?SSLMODE not set}"

# For clarity, log which user/host we will connect with
echo "[Neon-only script] Using NEON_USER='$NEON_USER' on host='$NEON_HOST'"
echo "DB=$NEON_DB, SSLMODE=$SSLMODE"

###############################################################################
# 2) The database + user we want to drop and re-create
###############################################################################
DB_NAME="coop-members"
DB_USER="coop-members"

###############################################################################
# 3) Helper function to run psql
###############################################################################
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

###############################################################################
# 4) Drop the database (if it exists)
###############################################################################
echo ""
echo "=== Dropping database '$DB_NAME' (if exists) ==="
run_psql "DROP DATABASE IF EXISTS \"$DB_NAME\";"

###############################################################################
# (Optional) Drop owned objects in other DBs, if user existed previously
###############################################################################
# If you want to ensure no leftover objects remain in *other* databases:
# echo ""
# echo "=== Dropping owned objects by '$DB_USER' (if any) ==="
# run_psql "DROP OWNED BY \"$DB_USER\" CASCADE;"

###############################################################################
# 5) Drop the user (if it exists)
###############################################################################
echo ""
echo "=== Dropping user '$DB_USER' (if exists) ==="
run_psql "DROP ROLE IF EXISTS \"$DB_USER\";"

###############################################################################
# 6) Create the user (Neon requires a password)
###############################################################################
echo ""
echo "=== Creating user '$DB_USER' with password '$NEON_PASSWORD' ==="
run_psql "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$NEON_PASSWORD';"

###############################################################################
# 7) Create the database as NEON_USER (not transferring ownership)
###############################################################################
echo ""
echo "=== Creating database '$DB_NAME' as NEON_USER='$NEON_USER' ==="
run_psql "CREATE DATABASE \"$DB_NAME\";"

###############################################################################
# 8) Grant privileges to DB_USER
###############################################################################
echo ""
echo "=== Granting privileges on database '$DB_NAME' to '$DB_USER' ==="
run_psql "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

# Depending on your needs, you might also want:
# - GRANT CREATE, CONNECT, TEMP ON DATABASE ...
# - GRANT USAGE ON SCHEMA public TO "$DB_USER";
# - etc.

###############################################################################
# 9) Verification checks
###############################################################################
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

###############################################################################
# Done
###############################################################################
echo ""
echo "=== Done! '$DB_NAME' is re-created by '$NEON_USER'. ==="
echo "=== '$DB_USER' can now connect and perform operations. ==="
echo "    Connected with $NEON_USER@$NEON_HOST (Neon)."
echo "    New user password = '$NEON_PASSWORD' (sample)."

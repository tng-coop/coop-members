#!/usr/bin/env bash
#
# remove-recreate-db.sh
#
# A script to remove (DROP) and recreate (CREATE) the "open-members" database,
# then create a minimal required table (e.g., "members").
#
# Usage:
#   chmod +x remove-recreate-db.sh
#   ./remove-recreate-db.sh
#
# Make sure you have psql installed and the appropriate environment variables set:
#   export PGUSER="postgres"
#   export PGPASSWORD="mysecret"
#   export PGHOST="localhost"
#   export PGPORT="5432"
#
# Or add them as command-line options below (-U, -h, -p).
# Adjust as needed for your environment.

DB_NAME="open-members"

# Database to connect to for administrative commands (like DROP/CREATE):
ADMIN_DB="postgres"

echo "=== Dropping $DB_NAME (if exists) ==="
psql -d "$ADMIN_DB" -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

echo "=== Creating $DB_NAME ==="
psql -d "$ADMIN_DB" -c "CREATE DATABASE \"$DB_NAME\";"

echo "=== Creating basic table in $DB_NAME ==="
psql -d "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS public.members (
  id SERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
EOF

echo "=== Done! $DB_NAME has been recreated with the 'members' table. ==="

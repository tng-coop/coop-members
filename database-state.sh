#!/usr/bin/env bash
#
# database_state.sh
#
# A simple script to show the state of your PostgreSQL databases:
# - List all databases (connect to "postgres" by default)
# - Show schemas in a specified database
# - Show tables in those schemas
#
# Usage: ./database_state.sh [database_name]

DB_NAME=${1:-postgres}

# Optionally, set connection details here or via environment variables:
# export PGUSER="myuser"
# export PGPASSWORD="mypassword"
# export PGHOST="localhost"
# export PGPORT="5532"

echo "=== 1. Listing all databases ==="
psql -d postgres -c "\l"

echo ""
echo "=== 2. Showing schemas in '$DB_NAME' ==="
psql -d "$DB_NAME" -c "\dn"

echo ""
echo "=== 3. Showing tables in '$DB_NAME' (public schema) ==="
psql -d "$DB_NAME" -c "\dt public.*"

echo ""
echo "=== 4. Done! ==="

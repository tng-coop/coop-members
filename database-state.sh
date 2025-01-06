#!/usr/bin/env bash
#
# database-state.sh
#
# A script to show a comprehensive state of your PostgreSQL setup in one of three modes:
#
#   1) Neon Mode (if first arg is "neon") - connects via environment variables:
#        NEON_USER, NEON_PASSWORD, NEON_HOST, NEON_DB, SSLMODE (default "require")
#   2) GitHub Actions Mode (if GITHUB_ACTIONS="true") - uses user=postgres, pass=postgres,
#        host=127.0.0.1, port=5432
#   3) Local Mode (if an OS-level user "postgres" exists) - re-runs as that user and uses
#        local socket peer/trust.
#
# Usage:
#   ./database-state.sh [mode] [DB_NAME]
#
# Examples:
#   ./database-state.sh neon        (inspects the DB named in $NEON_DB)
#   ./database-state.sh neon mydb   (inspects "mydb" on Neon)
#   ./database-state.sh             (if GITHUB_ACTIONS=true or if local OS postgres user)
#   ./database-state.sh mylocaldb   (ditto, specifying a local or GHA DB name)
#
# The script then prints various DB info:
#   1)  Port used
#   2)  IP, listen_addresses, SSL usage
#   3)  OS-level TCP check
#   4)  Version/current_user
#   5)  All DBs
#   6)  Schemas
#   7)  Tables in public
#   8)  Roles
#   9)  Extensions
#   10) DB size
#   11) Config paths
#   12) Key memory/conn settings
#   13) Basic DB stats
#   14) Table sizes
#   15) Active connections
#   16) Index usage stats
#   17) Largest indexes
#   18) Replication status
#   19) pg_hba.conf contents (if accessible locally)
#   20) Row-Level Security status
#   21) RLS policies

set -e  # Exit on error

##############################################################################
# 1) Parse Args: mode + DB_NAME
##############################################################################
MODE="$1"       # Could be "neon" or empty if not specified
if [ "$MODE" = "neon" ]; then
  # shift so that $2 becomes DB_NAME
  shift
fi

DB_NAME="${1:-postgres}"  # default to "postgres" if no second arg

echo "Analyzing DB = '$DB_NAME'..."

##############################################################################
# 2) Decide connection logic
#    Priority:
#      if MODE="neon" => NEON
#      else if GITHUB_ACTIONS="true" => GHA mode
#      else if local OS user "postgres" => local socket
#      else => error
##############################################################################
if [ "$MODE" = "neon" ]; then
  echo "[Neon mode] Connecting to NEON with environment vars: NEON_USER, NEON_PASSWORD, NEON_HOST, NEON_DB"
  # Check required env vars
  if [ -z "$NEON_USER" ] || [ -z "$NEON_PASSWORD" ] || [ -z "$NEON_HOST" ] || [ -z "$NEON_DB" ]; then
    echo "ERROR: NEON_USER, NEON_PASSWORD, NEON_HOST, or NEON_DB is not set. Cannot proceed."
    exit 1
  fi

  # Default SSLMODE to "require" if not set
  : "${SSLMODE:=require}"

  echo " NEON_USER=$NEON_USER"
  echo " NEON_HOST=$NEON_HOST"
  echo " NEON_DB=$NEON_DB"
  echo " SSLMODE=$SSLMODE (default is 'require')"

  function run_psql_db() {
    local db="$1"
    shift
    PGPASSWORD="$NEON_PASSWORD" psql -X -A -q -t \
      --host="$NEON_HOST" \
      --port="5432" \
      --username="$NEON_USER" \
      --dbname="$db" \
      --set=sslmode="$SSLMODE" \
      "$@"
  }

elif [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[CI mode] GITHUB_ACTIONS=true => Using TCP with user=postgres, pass=postgres, host=127.0.0.1, port=5432."
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="postgres"

  function run_psql_db() {
    local db="$1"
    shift
    PGPASSWORD="$DBPASS" psql -X -A -q -t \
      -h "$DBHOST" -p "$DBPORT" -U "$DBUSER" -d "$db" "$@"
  }

elif id postgres &>/dev/null; then
  echo "[Local mode] Found OS user 'postgres'."
  CURRENT_USER="$(id -un)"
  if [ "$CURRENT_USER" != "postgres" ]; then
    echo "Re-executing script as OS user 'postgres'..."
    exec sudo -u postgres bash "$0" "$MODE" "$DB_NAME"
    # 'exec' replaces this process with the new one
  fi

  # Now we're actually user=postgres locally => local socket
  function run_psql_db() {
    local db="$1"
    shift
    psql -X -A -q -t -d "$db" "$@"
  }

else
  echo "ERROR: Not Neon mode, not GitHub Actions, and no OS user 'postgres' found. Don't know how to connect."
  echo "Usage examples:"
  echo "  ./database-state.sh neon        # for NEON"
  echo "  ./database-state.sh             # for GHA or local dev"
  exit 1
fi

##############################################################################
# 3) Helper to run a single-line query
##############################################################################
run_single_line() {
  local db="$1"
  shift
  local output
  output="$(run_psql_db "$db" -c "$*")"
  echo "$output" | tr -d '[:space:]'
}

##############################################################################
# 4) Now the same logic for steps 1..19
##############################################################################
echo ""
echo "=== 1. Checking the current port used by '$DB_NAME' ==="
DB_PORT="$(run_single_line "$DB_NAME" "SHOW port;" 2>/dev/null || true)"
if [ -z "$DB_PORT" ]; then
  echo "Could not detect port from Postgres. Possibly local socket => 'unknown'."
  DB_PORT="unknown"
else
  echo "Port (from Postgres) = $DB_PORT"
fi

echo ""
echo "=== 2. Checking IP, Listen Addresses, and SSL usage from Postgres side ==="
echo "[listen_addresses]:"
run_psql_db "$DB_NAME" -c "SHOW listen_addresses;"
echo ""
echo "[ssl]:"
run_psql_db "$DB_NAME" -c "SHOW ssl;"
echo ""
echo "[inet_server_addr, inet_server_port]:"
run_psql_db "$DB_NAME" -c "SELECT inet_server_addr() AS ip_bound, inet_server_port() AS port_bound;"

echo ""
echo "=== 3. Checking OS-level TCP listening status for port $DB_PORT ==="
if [ "$DB_PORT" = "unknown" ]; then
  echo "Skipping, port is unknown (likely local socket only)."
else
  if command -v ss >/dev/null 2>&1; then
    echo "Using 'ss' to check listening sockets..."
    ss -lntp 2>/dev/null | grep ":$DB_PORT " || echo "No line matching ':$DB_PORT ' in ss output."
  elif command -v netstat >/dev/null 2>&1; then
    echo "Using 'netstat' to check listening sockets..."
    netstat -lntp 2>/dev/null | grep ":$DB_PORT " || echo "No line matching ':$DB_PORT ' in netstat output."
  else
    echo "Neither 'ss' nor 'netstat' found; cannot check OS-level listening on port $DB_PORT."
  fi
fi

echo ""
echo "=== 4. Checking PostgreSQL version and current user ==="
run_psql_db "$DB_NAME" -c "SELECT current_user AS user, version() AS postgres_version;"

echo ""
echo "=== 5. Listing all databases (connecting to 'postgres' DB by default) ==="
# In Neon mode, you might or might not actually have a 'postgres' DB.
# We'll try 'postgres' first, but if that fails, we fallback to $DB_NAME:
if ! run_psql_db "postgres" -c "\l" 2>/dev/null; then
  run_psql_db "$DB_NAME" -c "\l"
fi

echo ""
echo "=== 6. Showing schemas in '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "\dn"

echo ""
echo "=== 7. Showing tables in '$DB_NAME' (public schema) ==="
run_psql_db "$DB_NAME" -c "\dt public.*"

echo ""
echo "=== 8. Listing roles (users) in '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "\du"

echo ""
echo "=== 9. Listing installed extensions in '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "\dx"

echo ""
echo "=== 10. Checking size of '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME')) AS database_size;"

echo ""
echo "=== 11. Checking Postgres config paths (data_directory, config_file, hba_file) ==="
run_psql_db "$DB_NAME" -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN ('data_directory', 'config_file', 'hba_file')
  ORDER BY name;
"

echo ""
echo "=== 12. Checking memory and connection settings (shared_buffers, etc.) ==="
run_psql_db "$DB_NAME" -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'max_connections'
  )
  ORDER BY name;
"

echo ""
echo "=== 13. Basic DB stats from pg_stat_database for '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "
  SELECT datname,
         numbackends,
         xact_commit,
         xact_rollback,
         blks_read,
         blks_hit,
         temp_files,
         temp_bytes
    FROM pg_stat_database
   WHERE datname = '$DB_NAME';
"

echo ""
echo "=== 14. Listing table sizes in '$DB_NAME'.public schema (descending) ==="
run_psql_db "$DB_NAME" -c "
  SELECT relname AS table_name,
         pg_size_pretty(pg_relation_size(relid)) AS table_size,
         n_live_tup AS approximate_row_count
    FROM pg_stat_user_tables
   ORDER BY pg_relation_size(relid) DESC
   LIMIT 20;
"

echo ""
echo "=== 15. Showing current connections/queries in '$DB_NAME' (pg_stat_activity) ==="
run_psql_db "$DB_NAME" -c "
  SELECT pid,
         usename,
         application_name,
         client_addr,
         state,
         wait_event_type,
         query_start,
         now() - query_start AS query_runtime,
         LEFT(query, 200) AS current_query
    FROM pg_stat_activity
   WHERE datname = '$DB_NAME'
   ORDER BY query_start DESC;
"

echo ""
echo "=== 16. Index usage stats (pg_stat_user_indexes) for '$DB_NAME' ==="
run_psql_db "$DB_NAME" -c "
  SELECT i.relname AS index_name,
         pg_size_pretty(pg_relation_size(i.oid)) AS index_size,
         idx_scan,
         idx_tup_read,
         idx_tup_fetch
    FROM pg_stat_user_indexes ui
    JOIN pg_class i ON i.oid = ui.indexrelid
   ORDER BY idx_scan DESC
   LIMIT 20;
"

echo ""
echo "=== 17. Listing largest indexes in '$DB_NAME'.public schema ==="
run_psql_db "$DB_NAME" -c "
  SELECT c.relname AS index_name,
         pg_size_pretty(pg_relation_size(c.oid)) AS index_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.relkind = 'i'
     AND n.nspname = 'public'
   ORDER BY pg_relation_size(c.oid) DESC
   LIMIT 20;
"

echo ""
echo "=== 18. Checking replication status (pg_stat_replication) [if primary server] ==="
run_psql_db "$DB_NAME" -c "
  SELECT pid,
         usename,
         application_name,
         client_addr,
         state,
         sync_state,
         sent_lsn,
         write_lsn,
         flush_lsn,
         replay_lsn
    FROM pg_stat_replication;
"

echo ""
echo "=== 19. Checking pg_hba.conf lines to see how password auth is configured ==="
HBA_FILE="$(run_single_line "$DB_NAME" "SHOW hba_file;" 2>/dev/null)"

if [ -n "$HBA_FILE" ] && [ -r "$HBA_FILE" ]; then
  echo "pg_hba.conf is located at: $HBA_FILE"
  echo "Below are non-comment lines (host, local, auth methods, etc.):"
  echo "--------------------------------------------------------------------------"
  grep -vE '^\s*#' "$HBA_FILE" | sed '/^\s*$/d'
  echo "--------------------------------------------------------------------------"
  echo "Look for lines like 'md5', 'scram-sha-256', 'peer', 'trust', etc."
else
  echo "Can't read $HBA_FILE (file not found or no permission)."
  echo "Try running this script as OS 'postgres' if needed."
fi

##############################################################################
# 5) New: Check Row-Level Security (RLS)
##############################################################################

echo ""
echo "=== 20. Checking Row-Level Security (RLS) status on tables ==="
run_psql_db "$DB_NAME" -c "
  SELECT
    oid::regclass AS table_name,
    relrowsecurity AS rls_enabled,
    relforcerowsecurity AS rls_forced
  FROM pg_class
  WHERE relkind = 'r' -- regular table
  ORDER BY table_name;
"

echo ""
echo "=== 21. Listing all RLS policies (from pg_policies) ==="
run_psql_db "$DB_NAME" -c "
SELECT
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  permissive,
  qual,
  with_check
FROM pg_policies
ORDER BY schemaname, tablename, policyname;

"

echo ""
echo "=== Done! ==="

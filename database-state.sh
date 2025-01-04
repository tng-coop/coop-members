#!/usr/bin/env bash
#
# database-state.sh
#
# A script to show a comprehensive state of your PostgreSQL setup—either locally
# (using the OS 'postgres' user and local socket) or in CI (TCP to 127.0.0.1:5432
# as user=postgres, password=postgres).  No manual toggles or environment vars!
#
# Usage:  ./database-state.sh [DB_NAME]
#   If DB_NAME is not provided, defaults to "postgres".
#
# It prints:
#   1) Port used by DB
#   2) IP, listen_addresses, SSL usage
#   3) OS-level TCP check
#   4) Version/current_user
#   5) All DBs
#   6) Schemas
#   7) Tables in public
#   8) Roles
#   9) Extensions
#   10) DB size
#   11) Config paths
#   12) Key memory/conn settings
#   13) Basic DB stats
#   14) Table sizes
#   15) Active connections
#   16) Index usage stats
#   17) Largest indexes
#   18) Replication status
#   19) pg_hba.conf contents

set -e  # Exit on error

##############################################################################
# 0) Decide "Local Mode" vs. "CI Mode"
#    - If GITHUB_ACTIONS="true", use TCP: host=127.0.0.1, user=postgres, pass=postgres.
#    - Else if an OS user 'postgres' exists, re-run as that user (local socket).
#    - Otherwise, error out.
##############################################################################
if [ "$GITHUB_ACTIONS" = "true" ]; then
  echo "[CI mode] GITHUB_ACTIONS=true => Using TCP with user=postgres, pass=postgres."
  DBHOST="127.0.0.1"
  DBPORT="5432"
  DBUSER="postgres"
  DBPASS="postgres"

  run_psql_db() {
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
    exec sudo -u postgres bash "$0" "$@"
    # 'exec' replaces this process with the new one; no more code below runs here.
  fi

  # Now we're actually user=postgres locally, so psql uses local socket trust.
  run_psql_db() {
    local db="$1"
    shift
    psql -X -A -q -t -d "$db" "$@"
  }

else
  echo "ERROR: Not GitHub Actions, and no OS user 'postgres' found. Don't know how to connect."
  echo "Please either run on a system with an OS user 'postgres' or set GITHUB_ACTIONS=true."
  exit 1
fi

##############################################################################
# 1) Which DB are we analyzing?
##############################################################################
DB_NAME="${1:-postgres}"
echo "Analyzing DB = '$DB_NAME'..."

##############################################################################
# 2) Helper to quickly run a command capturing single-line output
##############################################################################
run_single_line() {
  # Usage: run_single_line <db> <sql>
  local db="$1"
  shift
  local output
  output="$(run_psql_db "$db" -c "$*")"
  # Trim whitespace
  echo "$output" | tr -d '[:space:]'
}

echo ""
echo "=== 1. Checking the current port used by '$DB_NAME' ==="
DB_PORT="$(run_single_line "$DB_NAME" "SHOW port;" 2>/dev/null || true)"
if [ -z "$DB_PORT" ]; then
  echo "Could not detect port from Postgres. Possibly local socket only => 'unknown'."
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
  echo "Skipping, port is unknown (likely local socket usage)."
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
echo "=== 5. Listing all databases (connect to 'postgres' DB by default) ==="
run_psql_db "postgres" -c "\l"

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

echo ""
echo "=== Done! ==="

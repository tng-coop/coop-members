#!/usr/bin/env bash
#
# database-state.sh
#
# A script to show a highly comprehensive state of your PostgreSQL setup:
#
#  1)  Port used by the specified database
#  2)  IP, Listen Addresses, SSL usage from Postgres
#  3)  OS-level check to see if the port is open (TCP)
#  4)  PostgreSQL version and current user
#  5)  List all databases
#  6)  Schemas in the specified database
#  7)  Tables in the public schema
#  8)  Roles (users)
#  9)  Extensions
# 10)  DB size
# 11) Postgres config paths (data_directory, config_file, hba_file)
# 12) Key memory/connection settings (shared_buffers, effective_cache_size, max_connections)
# 13) Basic DB stats from pg_stat_database
# 14) Table sizes in the specified DB (public schema)
# 15) Active connections overview (pg_stat_activity)
# 16) Index usage stats (pg_stat_user_indexes)
# 17) Largest indexes (public schema)
# 18) Replication status (pg_stat_replication) [if primary server]
# 19) (NEW) Inspect pg_hba.conf contents to see the auth methods used

DB_NAME=${1:-postgres}

# Optionally, set connection details here or via environment variables:
# export PGUSER="myuser"
# export PGPASSWORD="mypassword"
# export PGHOST="localhost"
# export PGPORT="5432"  # if needed, or rely on local socket auto-detection

echo "=== 1. Checking the current port used by '$DB_NAME' ==="
DB_PORT=$(psql -d "$DB_NAME" -X -A -t -c "SHOW port;" 2>/dev/null | tr -d '[:space:]')
if [ -z "$DB_PORT" ]; then
  echo "Could not detect port from Postgres. Possibly using a local socket with no TCP. Falling back to 'unknown'."
  DB_PORT="unknown"
else
  echo "Port (from Postgres): $DB_PORT"
fi

echo ""
echo "=== 2. Checking IP, Listen Addresses, and SSL usage from Postgres side ==="
echo "Listen Addresses:"
psql -d "$DB_NAME" -c "SHOW listen_addresses;"
echo ""
echo "SSL Enabled?"
psql -d "$DB_NAME" -c "SHOW ssl;"
echo ""
echo "Actual IP for current session (inet_server_addr, inet_server_port):"
psql -d "$DB_NAME" -c "SELECT inet_server_addr() AS ip_bound, inet_server_port() AS port_bound;"

echo ""
echo "=== 3. Checking OS-level TCP listening status for port $DB_PORT ==="
if [ "$DB_PORT" = "unknown" ]; then
  echo "Skipping, because the port is unknown (likely local socket only)."
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
psql -d "$DB_NAME" -c "SELECT current_user AS user, version() AS postgres_version;"

echo ""
echo "=== 5. Listing all databases (connects to 'postgres' by default) ==="
psql -d postgres -c "\l"

echo ""
echo "=== 6. Showing schemas in '$DB_NAME' ==="
psql -d "$DB_NAME" -c "\dn"

echo ""
echo "=== 7. Showing tables in '$DB_NAME' (public schema) ==="
psql -d "$DB_NAME" -c "\dt public.*"

echo ""
echo "=== 8. Listing roles (users) in '$DB_NAME' ==="
psql -d "$DB_NAME" -c "\du"

echo ""
echo "=== 9. Listing installed extensions in '$DB_NAME' ==="
psql -d "$DB_NAME" -c "\dx"

echo ""
echo "=== 10. Checking size of '$DB_NAME' ==="
psql -d "$DB_NAME" -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME')) AS database_size;"

################################################################################
# 11) Postgres config paths
################################################################################
echo ""
echo "=== 11. Checking Postgres config paths (data_directory, config_file, hba_file) ==="
psql -d "$DB_NAME" -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN ('data_directory', 'config_file', 'hba_file')
  ORDER BY name;
"

################################################################################
# 12) Key memory/connection settings
################################################################################
echo ""
echo "=== 12. Checking memory and connection settings ==="
psql -d "$DB_NAME" -c "
  SELECT name, setting
  FROM pg_settings
  WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'max_connections'
  )
  ORDER BY name;
"

################################################################################
# 13) Basic DB stats from pg_stat_database
################################################################################
echo ""
echo "=== 13. Basic DB stats from pg_stat_database for '$DB_NAME' ==="
psql -d "$DB_NAME" -c "
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

################################################################################
# 14) Table sizes in public schema (descending order)
################################################################################
echo ""
echo "=== 14. Listing table sizes in '$DB_NAME'.public schema ==="
psql -d "$DB_NAME" -c "
  SELECT relname AS table_name,
         pg_size_pretty(pg_relation_size(relid)) AS table_size,
         n_live_tup AS approximate_row_count
    FROM pg_stat_user_tables
   ORDER BY pg_relation_size(relid) DESC
   LIMIT 20;
"

################################################################################
# 15) Real-time active connections overview
################################################################################
echo ""
echo "=== 15. Showing current connections/queries in '$DB_NAME' (pg_stat_activity) ==="
psql -d "$DB_NAME" -c "
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

################################################################################
# 16) Index usage stats (pg_stat_user_indexes)
################################################################################
echo ""
echo "=== 16. Index usage stats (pg_stat_user_indexes) for '$DB_NAME' ==="
psql -d "$DB_NAME" -c "
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

################################################################################
# 17) Largest indexes in public schema
################################################################################
echo ""
echo "=== 17. Listing largest indexes in '$DB_NAME'.public schema ==="
psql -d "$DB_NAME" -c "
  SELECT c.relname AS index_name,
         pg_size_pretty(pg_relation_size(c.oid)) AS index_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.relkind = 'i'
     AND n.nspname = 'public'
   ORDER BY pg_relation_size(c.oid) DESC
   LIMIT 20;
"

################################################################################
# 18) Replication status (pg_stat_replication)
################################################################################
echo ""
echo "=== 18. Checking replication status (pg_stat_replication) [if primary server] ==="
psql -d "$DB_NAME" -c "
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

################################################################################
# 19) Check pg_hba.conf contents for authentication lines
################################################################################
echo ""
echo "=== 19. Checking pg_hba.conf lines to see how password auth is configured ==="
HBA_FILE=$(psql -d "$DB_NAME" -X -A -t -c "SHOW hba_file;" 2>/dev/null | tr -d '[:space:]')

if [ -n "$HBA_FILE" ] && [ -r "$HBA_FILE" ]; then
  echo "pg_hba.conf is located at: $HBA_FILE"
  echo "Below are the non-comment lines (showing host, local, auth methods, etc.):"
  echo "--------------------------------------------------------------------------"
  grep -vE '^\s*#' "$HBA_FILE" | sed '/^\s*$/d'
  echo "--------------------------------------------------------------------------"
  echo "Look for lines like 'md5', 'scram-sha-256', 'peer', or 'trust' to see if a password is required."
else
  echo "Can't read $HBA_FILE (file not found or no permission)."
  echo "Try running this script as a superuser or the 'postgres' OS user if needed."
fi

echo ""
echo "=== Done! ==="

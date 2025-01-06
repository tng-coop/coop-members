#!/usr/bin/env bash

# Exit immediately on error
set -e

# Check if all required environment variables are set
if [[ -z "$NEON_USER" || -z "$NEON_PASSWORD" || -z "$NEON_HOST" || -z "$NEON_DB" || -z "$SSLMODE" ]]; then
  echo "Error: One or more required environment variables are not set."
  echo "Ensure the following environment variables are set: NEON_USER, NEON_PASSWORD, NEON_HOST, NEON_DB, SSLMODE"
  exit 1
fi

# Build the connection string
CONNECTION_STRING="postgres://${NEON_USER}:${NEON_PASSWORD}@${NEON_HOST}:5432/${NEON_DB}?sslmode=${SSLMODE}"

# Generate a unique email
UNIQUE_EMAIL="john.doe.$(date +%s)@example.com"

# Define the SQL statement to insert a row with a unique email
SQL_STATEMENT="INSERT INTO members (first_name, last_name, email) VALUES ('John', 'Doe', '$UNIQUE_EMAIL');"

# Execute the SQL statement using psql
echo "Inserting row into database..."
psql "$CONNECTION_STRING" -c "$SQL_STATEMENT"

echo "Row inserted successfully with email: $UNIQUE_EMAIL"

#!/usr/bin/env bash

# Exit immediately on error
set -e

# Name of your local database
DB_NAME="coop-members"
# (Optional) If you typically connect as a specific user, you can add `user=...`:
# e.g., CONNECTION_STRING="postgres://myuser@/${DB_NAME}"

CONNECTION_STRING="postgres:///${DB_NAME}"

# Generate a unique email using the current timestamp
UNIQUE_EMAIL="john.doe.$(date +%s)@example.com"

# Define the SQL statement to insert a row with the unique email
SQL_STATEMENT="INSERT INTO members (first_name, last_name, email) VALUES ('John', 'Doe', '$UNIQUE_EMAIL');"

echo "Inserting row into local database via default socket..."
psql "$CONNECTION_STRING" -c "$SQL_STATEMENT"

echo "Row inserted successfully with email: $UNIQUE_EMAIL"

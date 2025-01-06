#!/usr/bin/env bash
#
# show_neon_env.sh
# 
# A simple script to show the current Neon environment variables.

####################################
# Optional: Load from a .env file. #
####################################
# If you store your Neon variables in a file named '.env',
# uncomment the following lines to source them automatically.
#
# if [ -f .env ]; then
#   # Export each variable in .env to the current shell,
#   # ignoring any commented lines.
#   export $(grep -v '^[[:space:]]*#' .env | xargs)
# fi

########################################
# Display the Neon-related environment #
########################################
echo "export NEON_USER=\"${NEON_USER}\""
echo "export NEON_PASSWORD=\"${NEON_PASSWORD}\""
echo "export NEON_HOST=\"${NEON_HOST}\""
echo "export NEON_DB=\"${NEON_DB}\""
echo "export SSLMODE=\"${SSLMODE}\""

export DATABASE_URL="postgres://${NEON_USER}:${NEON_PASSWORD}@${NEON_HOST}:5432/${NEON_DB}?sslmode=${SSLMODE}"
npx postgraphile --connection $DATABASE_URL --port 5000 --disable-graphiql

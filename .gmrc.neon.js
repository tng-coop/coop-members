/**
 * Graphile Migrate configuration (.gmrc.neon.js)
 * 
 * This file references environment variables for Neon credentials,
 * keeping the password out of version control.
 * 
 * Usage:
 *   npx graphile-migrate migrate --config .gmrc.neon.js
 */

module.exports = {
  // For the main database:
  connectionString: `postgres://${process.env.NEON_USER}:${process.env.NEON_PASSWORD}@${process.env.NEON_HOST}:5432/${process.env.NEON_DB}?sslmode=${process.env.SSLMODE}`,

  // For the shadow database (if you're using one):
  shadowConnectionString: `postgres://${process.env.NEON_USER}:${process.env.NEON_PASSWORD}@${process.env.NEON_HOST}:5432/${process.env.NEON_DB}-shadow?sslmode=${process.env.SSLMODE}`,

  // For dropping/creating databases (if your Neon role has privileges):
  rootConnectionString: `postgres://${process.env.NEON_USER}:${process.env.NEON_PASSWORD}@${process.env.NEON_HOST}:5432/postgres?sslmode=${process.env.SSLMODE}`,

  pgSettings: {
    // e.g. "search_path": "app_public,public"
  },

  placeholders: {
    // e.g. ":DATABASE_VISITOR": "!ENV"
  },

  afterReset: [],
  afterAllMigrations: [],
  afterCurrent: [],
};

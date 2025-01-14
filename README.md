# Coop Membership Management System

This document outlines the architecture and components for building a cooperative (coop) membership management system.

> **Note:** This file is **auto-generated** from `readme.json` by `readme.sh`.  
> Please **do not** edit `README.md` manually. Instead, update `readme.json` and run `./readme.sh`.

## Stack

- **Next.js**: Handles client-side rendering, server-side rendering, and routing (pages and API endpoints).
- **PostGraphile**: Auto-generates a GraphQL API from the PostgreSQL schema.
- **Graphile Migrate**: Manages and versions database schema changes.
- **MUI (Material UI)**: Provides UI components and theming for Next.js.
- **Playwright**: End-to-end (E2E) testing of the front end.

## Overview

**Goal:** Develop a web application for cooperative membership management.

**Member Features:**
- Create and manage membership profiles
- Renew memberships
- View membership status
- Update personal information (e.g., address, contact details)

**Admin Features:**
- Approve or reject membership applications
- Track membership fees
- Manage membership tiers or roles (e.g., Member, Admin, etc.)

## Objectives

### User Experience
Provide an intuitive interface for both regular members and administrators.

### Scalability
Use PostGraphile for auto-generated GraphQL and to handle increased membership growth.

### Maintainability
Use Graphile Migrate for versioned schema changes; follow Next.js best practices.

### Security
Protect data with secure auth, role-based access, and database-level rules.


## Architecture

### Diagram
```
[ Client Browser ]
      |
      v
[ Next.js ]
      |
(Apollo Client or similar)
      |
      v
[ PostGraphile ]
   (GraphQL)
      |
      v
[ PostgreSQL ]
```

### Notes
- Next.js handles rendering & routes.
- PostGraphile auto-generates GraphQL from Postgres.
- Graphile Migrate handles DB versioning.
- MUI for UI components.
- Playwright for E2E testing.

## Data Model

### members
```
id: Primary Key
first_name: String
last_name: String
email: Unique String
```

## Initial Database Design

A starting point for our SQL schema definitions using Graphile Migrate. Below is an example of a minimal table creation for members. (The actual .sql files can be tracked in migrations/.)

### SQL Examples

#### members
```sql
CREATE TABLE public.members (
  id SERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);
```

## Frontend

### Routes

- **/**: Home or dashboard
- **/login**: Login for members/admins
- **/register**: New membership application
- **/profile**: View/Edit member info
- **/admin**: Admin dashboard for approvals, membership management

### MUI Usage

- Theme: custom colors, typography
- Layout: AppBar, Drawer, Toolbar, Typography, etc.
- Forms: TextField, Checkbox, Button
- Data Tables: MUI Table for admin lists

## GraphQL API

### Auto-generated Resolvers
- Queries (e.g., allMembers, memberById)
- Mutations (e.g., createMember, updateMember)
- RLS-based permission if configured in Postgres

### Custom Logic
- Plugins / Smart Comments to tailor PostGraphile
- Database Functions / Triggers for advanced logic (if needed)

### Auth and Authz
- JWT or session-based with Next.js routes
- RLS in Postgres for row-level security

## Migrations

**Tool:** Graphile Migrate

**Workflow:**
- Write SQL (CREATE TABLE, ALTER TABLE) in .sql files (current.sql while in watch mode).
- Store migrations in version control (Git).
- Use graphile-migrate watch (dev) and graphile-migrate migrate (prod).
- A 'shadow' database may be used by Graphile Migrate to verify safe migrations; we set SHADOW_DATABASE_URL for that.
- Configuration files: .gmrc, .gmrc.gha, and .gmrc.neon.js. Each references different connection info (local, GHA, Neon).

## Security

- **ssl**: Between Next.js and PostGraphile if hosted separately
- **https**: Use HTTPS in production
- **role_based**: Postgres roles for queries/mutations
- **row_level_security**: Protect multi-tenant or user-specific data

## Testing and QA

- **Tool**: Playwright

**Tests:**
- E2E tests for registration, login, renewal, admin actions in a real browser
- Integration tests for GraphQL queries/mutations

**CI/CD:** GitHub Actions or similar for automated test runs

## Deployment and Hosting

- Option A: Next.js on Vercel, PostGraphile on Render, Postgres on Neon
- Option B: Windows Standalone Deployment (locally on a Windows machine)
- Neon Dashboard: https://console.neon.tech/app/projects
- GitHub Actions: https://github.com/tng-coop/coop-members/actions

## Dev Environments

### Primary Dev on Ubuntu
- Install PostgreSQL (sudo apt-get install postgresql)
- Install Node.js (via apt or nvm)
- Clone repo & npm install
- Set DATABASE_URL environment variable
- Run npx graphile-migrate up (migrations)
- npm run dev (Next.js), or run-postgraphile.sh

### Windows Home Machine
- Install PostgreSQL (Windows installer)
- Install Node.js (.exe from nodejs.org)
- Clone & install project
- Run migrations, start PostGraphile & Next.js, open localhost:<port>

## Roadmap / Next Steps

- Initialize Repo: Next.js + MUI + PostGraphile + Graphile Migrate
- Design DB Schema (members table for now)
- Implement Auth: session/JWT, RLS if needed
- Build Core Pages: registration, login, profile, admin
- Testing: Playwright E2E + integration
- Deployment: PaaS or self-host, with CI/CD for migrations/tests

## Conclusion

**Summary:** Combining Next.js, PostGraphile, Graphile Migrate, MUI, and Playwright yields a modern front end, auto-generated GraphQL, structured DB migrations, robust E2E testing, and flexible deployment.

**Next Steps:** Implement the minimal members table, integrate PostGraphile in Next.js, build membership features (if/when needed), and set up Playwright.

## Project File Structure

### Root
- README.md
- package.json
- tsconfig.json (if using TypeScript)
- .env (local environment variables)
- graphile.config.js (optional config for PostGraphile or Graphile Migrate)

### /src
- **pages**: Next.js pages and routes (e.g., /index.js, /login.js, etc.)
- **components**: Reusable React components with MUI styling
- **styles**: Global CSS or MUI theme configuration
- **api**: Optional if you embed PostGraphile or custom APIs in Next.js

### /migrations
- SQL migration files generated by Graphile Migrate (e.g., 000001.sql, 000002.sql)

### /tests
- **playwright**: Playwright E2E test specs and configuration


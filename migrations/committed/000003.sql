--! Previous: sha1:d44b05ccb5a1177dcff3250918b755fb1374a62b
--! Hash: sha1:b2fa232e98d76087906a09f1228a5373f982bdf6

BEGIN;

-- 1) Create roles (idempotent, marked NOLOGIN so Neon doesn't require a password)
DO $$
BEGIN
  CREATE ROLE anonymous NOLOGIN;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "anonymous" already exists. Skipping.';
END
$$;

DO $$
BEGIN
  CREATE ROLE member NOLOGIN;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "member" already exists. Skipping.';
END
$$;

DO $$
BEGIN
  CREATE ROLE admin NOLOGIN;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "admin" already exists. Skipping.';
END
$$;

-- 2) Allow these roles to use the public schema
GRANT USAGE ON SCHEMA public TO anonymous, member, admin;

-- 3) Enable row-level security on the "members" table
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

-- 4) Create a SELECT policy
--    Example: let everyone (including anonymous) see all rows
DROP POLICY IF EXISTS select_all_members ON public.members;
CREATE POLICY select_all_members
  ON public.members
  FOR SELECT
  TO anonymous
  USING (true);

-- 5) Create an UPDATE policy
--    Example: let the 'member' role update only *their own* record
DROP POLICY IF EXISTS update_own_member ON public.members;
CREATE POLICY update_own_member
  ON public.members
  FOR UPDATE
  TO member
  USING (id = current_setting('jwt.claims.member_id', true)::int);

-- 6) Grant privileges
GRANT SELECT ON public.members TO anonymous;
GRANT UPDATE ON public.members TO member;

COMMIT;

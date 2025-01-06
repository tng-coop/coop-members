--! Previous: sha1:d44b05ccb5a1177dcff3250918b755fb1374a62b
--! Hash: sha1:b034e253f51317fdf9679b2cc235657bc5caeba5

BEGIN;

-- 1) Create roles (idempotent) with a dummy password
DO $$
BEGIN
  CREATE ROLE anonymous WITH LOGIN PASSWORD 'random_password';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "anonymous" already exists. Skipping.';
END
$$;

DO $$
BEGIN
  CREATE ROLE member WITH LOGIN PASSWORD 'random_password';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "member" already exists. Skipping.';
END
$$;

DO $$
BEGIN
  CREATE ROLE admin WITH LOGIN PASSWORD 'random_password';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Role "admin" already exists. Skipping.';
END
$$;

-- 2) (Optional) If you want to remove login capability:
--    Neon might still complain if you remove login, but you can try:
-- ALTER ROLE anonymous NOLOGIN;
-- ALTER ROLE member NOLOGIN;
-- ALTER ROLE admin NOLOGIN;

-- 3) Allow roles to use the public schema
GRANT USAGE ON SCHEMA public TO anonymous, member, admin;

-- 4) Enable row-level security and define your policies...
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS select_all_members ON public.members;
CREATE POLICY select_all_members
  ON public.members
  FOR SELECT
  TO anonymous
  USING (true);

DROP POLICY IF EXISTS update_own_member ON public.members;
CREATE POLICY update_own_member
  ON public.members
  FOR UPDATE
  TO member
  USING (id = current_setting('jwt.claims.member_id', true)::int);

-- 5) Grant privileges
GRANT SELECT ON public.members TO anonymous;
GRANT UPDATE ON public.members TO member;

COMMIT;

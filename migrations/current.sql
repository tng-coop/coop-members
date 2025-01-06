BEGIN;

-- 1) Create roles
CREATE ROLE anonymous;
CREATE ROLE member;
CREATE ROLE admin;

-- 2) Allow these roles to use the public schema
GRANT USAGE ON SCHEMA public TO anonymous, member, admin;

-- 3) Enable row-level security on the "members" table
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

-- 4) Create a SELECT policy
--   Example: let everyone (including anonymous) see all rows
--   (Adjust to your needs. You might only want `member` to see them.)
DROP POLICY IF EXISTS select_all_members ON public.members;
CREATE POLICY select_all_members
  ON public.members
  FOR SELECT
  TO anonymous
  USING (true);

-- 5) Create an UPDATE policy
--   Example: let the 'member' role update only *their own* record
--   We'll match the 'member_id' from the composite JWT claims.
DROP POLICY IF EXISTS update_own_member ON public.members;
CREATE POLICY update_own_member
  ON public.members
  FOR UPDATE
  TO member
  USING (id = current_setting('jwt.claims.member_id', true)::int);

-- 6) Grant privileges to roles
--   - Let anonymous SELECT from members (if you want a public directory)
--   - Let member UPDATE members
GRANT SELECT ON public.members TO anonymous;
GRANT UPDATE ON public.members TO member;

COMMIT;

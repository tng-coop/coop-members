--! Previous: sha1:d44b05ccb5a1177dcff3250918b755fb1374a62b
--! Hash: sha1:18afaba41d7b83406a7d3cd778aceee5ef9082d7

BEGIN;

------------------------------------------------------------------------------
-- 1) Add a 'password_hash' column for storing hashed passwords (optional).
--    If you already store passwords elsewhere or don't need them, skip this.
------------------------------------------------------------------------------
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS password_hash text;

------------------------------------------------------------------------------
-- 2) Enable Row-Level Security (RLS) on the 'members' table
------------------------------------------------------------------------------
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

------------------------------------------------------------------------------
-- 3) Define RLS policies that rely on JWT claims
--    - We assume your JWT payload includes { "member_id": number, "role": "member" }
--    - If you also want an "anonymous" or "admin" path, add additional policies
------------------------------------------------------------------------------

-- Policy: allow SELECT if:
--   role = 'member' AND the 'member_id' in the JWT matches the row's 'id'
DROP POLICY IF EXISTS member_select_own ON public.members;
CREATE POLICY member_select_own
  ON public.members
  FOR SELECT
  TO public  -- the "public" or single DB user
  USING (
    current_setting('jwt.claims.role', true) = 'member'
    AND id = current_setting('jwt.claims.member_id', true)::int
  );

-- Policy: allow UPDATE if:
--   role = 'member' AND the 'member_id' in the JWT matches the row's 'id'
DROP POLICY IF EXISTS member_update_own ON public.members;
CREATE POLICY member_update_own
  ON public.members
  FOR UPDATE
  TO public
  USING (
    current_setting('jwt.claims.role', true) = 'member'
    AND id = current_setting('jwt.claims.member_id', true)::int
  );

COMMIT;

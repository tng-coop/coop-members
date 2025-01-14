--! Previous: -
--! Hash: sha1:8867b7ba1fe20d2f73c74c3cdc85c9b281ab8c9f

BEGIN;

-------------------------------------------------------------------------------
-- 1) Ensure pgcrypto is available (for hashing/checking passwords)
-------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-------------------------------------------------------------------------------
-- 2) Create the "members" table
-------------------------------------------------------------------------------
CREATE TABLE public.members (
  id SERIAL PRIMARY KEY,
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL  -- store hashed passwords (NOT NULL is recommended)
);

-- >>> Tell PostGraphile to omit standard create/update/delete for "members" <<<
COMMENT ON TABLE public.members IS E'@omit create,update,delete';

-------------------------------------------------------------------------------
-- 3) Revoke direct INSERT privileges from "public"
--    so that only our SECURITY DEFINER function can insert new members.
-------------------------------------------------------------------------------
REVOKE INSERT ON public.members FROM public;

-------------------------------------------------------------------------------
-- 4) Enable Row-Level Security (RLS) on the table
-------------------------------------------------------------------------------
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

-------------------------------------------------------------------------------
-- 5) Define the composite type for JWT tokens
-------------------------------------------------------------------------------
DROP TYPE IF EXISTS public.jwt_token CASCADE;
CREATE TYPE public.jwt_token AS (
  member_id INTEGER,
  role      TEXT
);

-------------------------------------------------------------------------------
-- 6) A function to "register" (sign up) new members:
--    - SECURITY DEFINER (so it can bypass RLS/permission checks)
--    - Checks for existing email
--    - Hashes the plaintext password
--    - Inserts the row
--    - Returns a jwt_token composite (so you can sign a JWT immediately)
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_member(
  in_first_name TEXT,
  in_last_name  TEXT,
  in_email      TEXT,
  in_password   TEXT
)
RETURNS public.jwt_token
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _id      INTEGER;
  _payload public.jwt_token;
BEGIN
  -- 1. Check if email already exists
  IF EXISTS(SELECT 1 FROM public.members WHERE email = in_email) THEN
    RAISE EXCEPTION 'A member with this email already exists';
  END IF;

  -- 2. Insert a new row with hashed password
  INSERT INTO public.members (first_name, last_name, email, password_hash)
  VALUES (
    in_first_name,
    in_last_name,
    in_email,
    crypt(in_password, gen_salt('bf'))  -- hashing
  )
  RETURNING id INTO _id;

  -- 3. Build a jwt_token payload to return
  _payload.member_id := _id;
  _payload.role      := 'member';

  RETURN _payload;
END;
$$;

-------------------------------------------------------------------------------
-- 7) A function to "login" existing members:
--    - Checks email/password
--    - Returns a jwt_token if correct
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.login_member(
  in_email    TEXT,
  in_password TEXT
)
RETURNS public.jwt_token
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result public.jwt_token;
  m public.members;
BEGIN
  -- 1. Look up the member by email
  SELECT *
    INTO m
    FROM public.members
   WHERE email = in_email
   LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No member found with that email';
  END IF;

  -- 2. Compare supplied password with stored hash
  IF crypt(in_password, m.password_hash) <> m.password_hash THEN
    RAISE EXCEPTION 'Invalid password';
  END IF;

  -- 3. Build and return the composite to be signed as JWT
  result.member_id := m.id;
  result.role      := 'member';
  RETURN result;
END;
$$;

-------------------------------------------------------------------------------
-- 8) Define Row-Level Security (RLS) policies (SELECT/UPDATE own row)
-------------------------------------------------------------------------------

-- Policy: SELECT only your own row
DROP POLICY IF EXISTS member_select_own ON public.members;
CREATE POLICY member_select_own
  ON public.members
  FOR SELECT
  TO public
  USING (
    current_setting('jwt.claims.role', true) = 'member'
    AND id = current_setting('jwt.claims.member_id', true)::int
  );

-- Policy: UPDATE only your own row
DROP POLICY IF EXISTS member_update_own ON public.members;
CREATE POLICY member_update_own
  ON public.members
  FOR UPDATE
  TO public
  USING (
    current_setting('jwt.claims.role', true) = 'member'
    AND id = current_setting('jwt.claims.member_id', true)::int
  )
  WITH CHECK (
    current_setting('jwt.claims.role', true) = 'member'
    AND id = current_setting('jwt.claims.member_id', true)::int
  );

COMMIT;

-------------------------------------------------------------------------------
-- 9) (Optional) A function to return the current_user (for debugging/demo)
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_db_user()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT current_user
$$;

COMMIT;

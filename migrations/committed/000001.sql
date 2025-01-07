--! Previous: -
--! Hash: sha1:66b587977cc4e88795e2958293625f2282ae29e8

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
  first_name TEXT NOT NULL,
  last_name  TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  password_hash TEXT  -- for storing hashed passwords
);

-------------------------------------------------------------------------------
-- 3) (Optional) Revoke direct INSERT privileges from "public"
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
  member_id integer,
  role text
);

-------------------------------------------------------------------------------
-- 6) A function to "register" new members (sign up)
--    - SECURITY DEFINER so it can bypass RLS/permission checks
--    - Hashes the plaintext password
--    - Inserts the new member row
--    - Returns (optionally) the JWT payload so you can chain it to a JWT if desired
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_member(
  in_first_name text,
  in_last_name  text,
  in_email      text,
  in_password   text
)
RETURNS public.jwt_token
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _id integer;
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

  -- 3. Build a payload (just like "login_member") in case you want
  --    to sign a JWT immediately after registration:
  _payload.member_id := _id;
  _payload.role      := 'member';

  RETURN _payload;
END;
$$;

-------------------------------------------------------------------------------
-- 7) A function to "login" existing members:
--    - Checks the stored password hash
--    - Returns the JWT payload if correct
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.login_member(in_email text, in_password text)
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

  -- 2. Compare supplied password with the stored hash
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
-- 8) Define RLS policies (SELECT/UPDATE)
--    - We assume a valid JWT with { "member_id": number, "role": "member" }
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

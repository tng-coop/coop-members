--! Previous: sha1:457384a3a7defa5715b9ee330b96a1b5f0c89360
--! Hash: sha1:d44b05ccb5a1177dcff3250918b755fb1374a62b

BEGIN;

-- 1) Define a composite type for your token
DROP TYPE IF EXISTS public.jwt_token CASCADE;
CREATE TYPE public.jwt_token AS (
  member_id integer,
  role text
);

-- 2) Define a login function that returns the composite type
CREATE OR REPLACE FUNCTION public.login_member(in_email text)
RETURNS public.jwt_token
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result public.jwt_token; 
  m public.members;
BEGIN
  SELECT * INTO m
    FROM public.members
   WHERE email = in_email;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No member found with that email';
  END IF;

  -- Instead of storing in a column, we build and return the composite
  result.member_id := m.id;
  result.role := 'member';

  RETURN result;  -- returning the composite type
END;
$$;

COMMIT;

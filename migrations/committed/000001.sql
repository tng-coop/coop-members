--! Previous: -
--! Hash: sha1:457384a3a7defa5715b9ee330b96a1b5f0c89360

CREATE TABLE public.members (
  id SERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);

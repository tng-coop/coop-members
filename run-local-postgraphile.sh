npx postgraphile \
  --schema public \
  --jwt-secret "SUPER_SECRET_TOKEN" \
  --jwt-token-identifier "public.jwt_token" \
  --enhance-graphiql
  

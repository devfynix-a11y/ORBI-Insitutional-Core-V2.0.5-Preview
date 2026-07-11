ALTER TABLE IF EXISTS orbi_auth.revoked_access_tokens
  ALTER COLUMN jti TYPE TEXT USING jti::text;

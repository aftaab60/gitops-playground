-- Runs once when Postgres starts with an empty data directory.
-- The Go API also runs CREATE TABLE IF NOT EXISTS on startup,
-- so this file just ensures the pgcrypto extension is present
-- (needed for gen_random_uuid() on Postgres < 13).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

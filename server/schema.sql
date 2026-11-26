-- Yarr! 07 accounts (Cloudflare D1, SQLite). Run once on a new database; safe to run again.
-- Nothing here names a person: an account is an id the player made up, hashes, and the game's progress.

-- one row per account. pw and rc are HMAC-SHA256 hashes keyed with the worker's secret (PEPPER): of the key the game
-- stretches from the password (PBKDF2, in the game, so the password itself never comes here), and of the recovery code
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,               -- the sign-in id, lower case: a-z 0-9 _ (3 to 16)
  salt TEXT NOT NULL,                -- 16 random bytes, hex
  pw TEXT NOT NULL,                  -- HMAC(PEPPER, "pw|" salt "|" key), hex
  rc TEXT NOT NULL,                  -- HMAC(PEPPER, "rc|" salt "|" recovery code), hex
  kdf INTEGER NOT NULL DEFAULT 1,    -- which stretching the game used for the key (1: PBKDF2-HMAC-SHA256, 100,000 rounds)
  created INTEGER NOT NULL,          -- seconds since 1970
  seen INTEGER NOT NULL              -- the last sign-in
) STRICT;

-- a device signed in: the SHA-256 of its token (the token itself is only on the device)
CREATE TABLE IF NOT EXISTS sessions (
  tok TEXT PRIMARY KEY,
  user TEXT NOT NULL,
  created INTEGER NOT NULL,
  seen INTEGER NOT NULL
) STRICT;
CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user);
CREATE INDEX IF NOT EXISTS sessions_seen ON sessions (seen);

-- the progress: the game's save as JSON, and how many times it has been written (rev), so two devices do not
-- overwrite each other without the player being asked
CREATE TABLE IF NOT EXISTS saves (
  user TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  rev INTEGER NOT NULL,
  updated INTEGER NOT NULL
) STRICT;

-- wrong tries, counted for a while: by id and by a hash of the caller's address (never the address itself)
CREATE TABLE IF NOT EXISTS tries (
  k TEXT PRIMARY KEY,
  n INTEGER NOT NULL,
  until INTEGER NOT NULL
) STRICT;
CREATE INDEX IF NOT EXISTS tries_until ON tries (until);

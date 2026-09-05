CREATE TABLE IF NOT EXISTS households (
  id          TEXT PRIMARY KEY,
  invite_code TEXT UNIQUE NOT NULL,
  child_name  TEXT NOT NULL DEFAULT 'あかちゃん',
  birth_date  INTEGER NOT NULL,
  is_preterm  INTEGER NOT NULL DEFAULT 0,
  municipality TEXT NOT NULL DEFAULT '',
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  household_id  TEXT REFERENCES households(id),
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  created_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS care_logs (
  id           TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id),
  kind         TEXT NOT NULL,
  time         INTEGER NOT NULL,
  detail       TEXT NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS care_logs_household_time ON care_logs(household_id, time DESC);

CREATE TABLE IF NOT EXISTS measurements (
  id           TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id),
  age_months   REAL NOT NULL,
  date         INTEGER NOT NULL,
  height_cm    REAL NOT NULL,
  weight_kg    REAL NOT NULL,
  head_cm      REAL NOT NULL,
  created_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS procedure_tasks (
  id               TEXT PRIMARY KEY,
  household_id     TEXT NOT NULL REFERENCES households(id),
  title            TEXT NOT NULL,
  category         TEXT NOT NULL,
  due_date         INTEGER,
  status           TEXT NOT NULL DEFAULT 'scheduled',
  assignee         TEXT NOT NULL DEFAULT 'unassigned',
  summary          TEXT NOT NULL DEFAULT '',
  documents        TEXT NOT NULL DEFAULT '[]',
  counter          TEXT NOT NULL DEFAULT '',
  online_available INTEGER NOT NULL DEFAULT 0,
  source_title     TEXT NOT NULL DEFAULT '',
  source_url       TEXT NOT NULL DEFAULT '',
  fetched_at       TEXT NOT NULL DEFAULT '',
  created_at       INTEGER NOT NULL
);

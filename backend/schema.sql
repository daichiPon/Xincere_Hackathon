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

-- パートナー招待コード。1コード=1回限り、発行から10分で失効。
-- households.invite_code(レガシー列)ではなくこのテーブルで検証する。
CREATE TABLE IF NOT EXISTS household_invites (
  code         TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id),
  expires_at   INTEGER NOT NULL,
  used_at      INTEGER,
  created_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS household_invites_household ON household_invites(household_id);

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

-- 制度・給付金マスタ(23区の子育て支援制度。世帯データとは独立、全ユーザー共通)
CREATE TABLE IF NOT EXISTS program_master (
  id                   TEXT PRIMARY KEY,
  ward                 TEXT NOT NULL,             -- 例: 世田谷区
  category             TEXT NOT NULL,             -- 例: 出産祝い金 / 医療費助成 / 産後ケア 等
  program_name         TEXT NOT NULL,
  min_age_months       INTEGER,                   -- 対象月齢の下限(NULL可)
  max_age_months       INTEGER,                   -- 対象月齢の上限(NULL可)
  income_condition     TEXT NOT NULL DEFAULT '',  -- 所得条件(自由記述)
  program_type         TEXT NOT NULL DEFAULT '',  -- 現金給付/実費償還/クーポン・利用料減免/現物給付/訪問・相談サービス
  amount_or_content    TEXT NOT NULL DEFAULT '',  -- 金額 or 現物給付の内容(上限額・実費償還等も自由記述で表現)
  application_channel  TEXT NOT NULL DEFAULT '',  -- 窓口 / 郵送 / オンライン
  required_documents   TEXT NOT NULL DEFAULT '',
  has_deadline         INTEGER NOT NULL DEFAULT 1,-- 締切のある申請=1 / いつでも使える・自動的なサービス=0(「やること」タスク化の判定に使う)
  deadline_rule        TEXT NOT NULL DEFAULT '',  -- 起算日と期限の説明(has_deadline=0なら空でよい)
  source_url           TEXT NOT NULL,             -- 出典 URL(必須。出典なし情報は登録不可)
  fetched_at           TEXT NOT NULL,             -- 取得日(必須。例: 2026-09-06)
  reviewed_by          TEXT NOT NULL DEFAULT '',  -- 金額を含む場合は人手レビュー者を必須にする運用
  notes                TEXT NOT NULL DEFAULT '',
  created_at           INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS program_master_ward ON program_master(ward);
CREATE INDEX IF NOT EXISTS program_master_category ON program_master(category);

-- 予防接種スケジュールマスタ(全国共通。区に依存しない標準スケジュール)
-- 出典・取得日は program_master と同じ運用(出典なし登録不可)。
CREATE TABLE IF NOT EXISTS vaccine_schedule (
  id                TEXT PRIMARY KEY,
  vaccine_name      TEXT NOT NULL,
  dose_label        TEXT NOT NULL,             -- 例: 1回目 / 追加 / 1期
  dose_number       INTEGER NOT NULL DEFAULT 1,-- 並び順(毎年接種は0)
  category          TEXT NOT NULL DEFAULT '定期', -- 定期 / 任意
  disease           TEXT NOT NULL DEFAULT '',  -- 予防する病気
  start_age_months  REAL,                      -- 標準的な接種開始月齢(1歳=12)
  end_age_months    REAL,                      -- 定期接種として受けられる上限月齢(NULL可)
  interval_note     TEXT NOT NULL DEFAULT '',  -- 前回からの間隔など
  notes             TEXT NOT NULL DEFAULT '',
  source_url        TEXT NOT NULL,
  fetched_at        TEXT NOT NULL,
  created_at        INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS vaccine_schedule_order ON vaccine_schedule(start_age_months, vaccine_name, dose_number);

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

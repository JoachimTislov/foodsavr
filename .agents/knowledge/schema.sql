PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS document_references (
  id INTEGER PRIMARY KEY,
  document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  ref_type TEXT NOT NULL,
  ref_value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS references_lookup ON document_references(ref_type, ref_value);

CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  harness TEXT NOT NULL,
  started_at TEXT NOT NULL,
  status TEXT NOT NULL,
  summary TEXT NOT NULL,
  transcript TEXT,
  raw_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS session_references (
  session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  ref_type TEXT NOT NULL,
  ref_value TEXT NOT NULL,
  PRIMARY KEY(session_id, ref_type, ref_value)
);

CREATE INDEX IF NOT EXISTS session_references_lookup
  ON session_references(ref_type, ref_value);

CREATE TABLE IF NOT EXISTS workflow_runs (
  run_id TEXT PRIMARY KEY,
  workflow_id TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  provider TEXT,
  raw_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workflow_run_artifacts (
  run_id TEXT NOT NULL REFERENCES workflow_runs(run_id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  kind TEXT NOT NULL,
  sha256 TEXT,
  PRIMARY KEY(run_id, path)
);

CREATE TABLE IF NOT EXISTS workflow_run_events (
  run_id TEXT NOT NULL REFERENCES workflow_runs(run_id) ON DELETE CASCADE,
  event_index INTEGER NOT NULL,
  timestamp TEXT,
  event_type TEXT NOT NULL,
  raw_json TEXT NOT NULL,
  PRIMARY KEY(run_id, event_index)
);

CREATE INDEX IF NOT EXISTS workflow_runs_status ON workflow_runs(status);
CREATE INDEX IF NOT EXISTS workflow_run_events_type ON workflow_run_events(event_type);

CREATE TABLE IF NOT EXISTS git_commits (
  sha TEXT PRIMARY KEY,
  author TEXT NOT NULL,
  email TEXT NOT NULL,
  authored_at TEXT NOT NULL,
  subject TEXT NOT NULL,
  message TEXT NOT NULL
);

-- commit/session/PR/issue/run/rebase-equivalence edges used by `agentctl trace` (#271)
CREATE TABLE IF NOT EXISTS trace_edges (
  src_type TEXT NOT NULL,
  src_id TEXT NOT NULL,
  dst_type TEXT NOT NULL,
  dst_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  via TEXT NOT NULL DEFAULT '',
  PRIMARY KEY(src_type, src_id, dst_type, dst_id, kind)
);

CREATE INDEX IF NOT EXISTS trace_edges_dst ON trace_edges(dst_type, dst_id, kind);

CREATE TABLE IF NOT EXISTS trace_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS document_search USING fts5(
  title,
  content,
  path UNINDEXED,
  content='documents',
  content_rowid='id'
);

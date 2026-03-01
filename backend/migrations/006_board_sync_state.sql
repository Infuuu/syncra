CREATE TABLE IF NOT EXISTS board_sync_state (
  board_id UUID PRIMARY KEY REFERENCES boards(id) ON DELETE CASCADE,
  latest_version BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO board_sync_state (board_id, latest_version)
SELECT b.id, COALESCE(MAX(so.version), 0)::bigint
FROM boards b
LEFT JOIN sync_operations so ON so.board_id = b.id
GROUP BY b.id
ON CONFLICT (board_id)
DO UPDATE SET latest_version = EXCLUDED.latest_version, updated_at = now();

CREATE INDEX IF NOT EXISTS idx_board_sync_state_latest_version ON board_sync_state(latest_version);

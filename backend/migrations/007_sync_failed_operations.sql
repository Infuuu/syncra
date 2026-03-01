CREATE TABLE IF NOT EXISTS sync_failed_operations (
  id BIGSERIAL PRIMARY KEY,
  actor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  board_id UUID REFERENCES boards(id) ON DELETE SET NULL,
  client_operation_id TEXT,
  operation_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status_code INTEGER NOT NULL,
  last_error_code TEXT,
  last_error_message TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 1,
  first_failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_failed_actor_client_op
  ON sync_failed_operations(actor_user_id, client_operation_id)
  WHERE client_operation_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sync_failed_actor_unresolved
  ON sync_failed_operations(actor_user_id, last_failed_at DESC)
  WHERE resolved_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_sync_failed_board_unresolved
  ON sync_failed_operations(board_id, last_failed_at DESC)
  WHERE resolved_at IS NULL;

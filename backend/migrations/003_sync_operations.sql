CREATE TABLE IF NOT EXISTS sync_operations (
  version BIGSERIAL PRIMARY KEY,
  board_id UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
  actor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_operation_id TEXT,
  operation_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sync_operations_board_version ON sync_operations(board_id, version);
CREATE INDEX IF NOT EXISTS idx_sync_operations_actor_version ON sync_operations(actor_user_id, version);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_operations_actor_client_op
  ON sync_operations(actor_user_id, client_operation_id)
  WHERE client_operation_id IS NOT NULL;

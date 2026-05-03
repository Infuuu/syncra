CREATE TABLE IF NOT EXISTS schema_migrations_temp (dummy int);

ALTER TABLE notes ALTER COLUMN board_id DROP NOT NULL;

-- Index to quickly find user's global notes
CREATE INDEX IF NOT EXISTS idx_notes_created_by_global ON notes(created_by, updated_at DESC) WHERE board_id IS NULL AND is_deleted = FALSE;

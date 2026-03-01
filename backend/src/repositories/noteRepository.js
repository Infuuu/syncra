const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const resolveClient = (client) => client || requirePool();

const mapNote = (row) => ({
  id: row.id,
  boardId: row.board_id,
  createdBy: row.created_by,
  title: row.title,
  content: row.content,
  version: Number(row.version),
  isDeleted: row.is_deleted,
  deletedAt: row.deleted_at,
  createdAt: row.created_at,
  updatedAt: row.updated_at
});

const createNote = async ({ client, noteInput }) => {
  const db = resolveClient(client);
  const { rows } = await db.query(
    `INSERT INTO notes (id, board_id, created_by, title, content, updated_at)
     VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5::jsonb, now())
     RETURNING id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at`,
    [
      noteInput.id,
      noteInput.boardId,
      noteInput.createdBy,
      noteInput.title,
      JSON.stringify(noteInput.content || {})
    ]
  );

  return rows[0] ? mapNote(rows[0]) : null;
};

const getNoteForUpdate = async ({ client, noteId }) => {
  const db = resolveClient(client);
  const { rows } = await db.query(
    `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
     FROM notes
     WHERE id = $1::uuid
     LIMIT 1
     FOR UPDATE`,
    [noteId]
  );
  return rows[0] ? mapNote(rows[0]) : null;
};

const getNoteById = async ({ noteId }) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
     FROM notes
     WHERE id = $1::uuid
     LIMIT 1`,
    [noteId]
  );
  return rows[0] ? mapNote(rows[0]) : null;
};

const updateNoteWithExpectedVersion = async ({ client, noteId, boardId, expectedVersion, patch }) => {
  const db = resolveClient(client);
  const values = [noteId, boardId];
  const updates = [];

  if (typeof patch.title === 'string') {
    values.push(patch.title.trim());
    updates.push(`title = $${values.length}`);
  }

  if (patch.content && typeof patch.content === 'object' && !Array.isArray(patch.content)) {
    values.push(JSON.stringify(patch.content));
    updates.push(`content = $${values.length}::jsonb`);
  }

  if (updates.length === 0) {
    return null;
  }

  values.push(expectedVersion);
  const expectedVersionIndex = values.length;

  const { rows } = await db.query(
    `UPDATE notes
     SET ${updates.join(', ')}, version = version + 1, updated_at = now()
     WHERE id = $1::uuid
       AND board_id = $2::uuid
       AND version = $${expectedVersionIndex}
       AND is_deleted = FALSE
     RETURNING id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at`,
    values
  );

  return rows[0] ? mapNote(rows[0]) : null;
};

const softDeleteNoteWithExpectedVersion = async ({ client, noteId, boardId, expectedVersion }) => {
  const db = resolveClient(client);
  const { rows } = await db.query(
    `UPDATE notes
     SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
     WHERE id = $1::uuid
       AND board_id = $2::uuid
       AND version = $3
       AND is_deleted = FALSE
     RETURNING id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at`,
    [noteId, boardId, expectedVersion]
  );

  return rows[0] ? mapNote(rows[0]) : null;
};

const listBoardNotes = async ({ boardId, limit = 100, offset = 0, cursor = null }) => {
  const db = requirePool();
  if (cursor && cursor.updatedAt && cursor.id) {
    const { rows } = await db.query(
      `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
       FROM notes
       WHERE board_id = $1::uuid
         AND is_deleted = FALSE
         AND (updated_at, id) < ($2::timestamptz, $3::uuid)
       ORDER BY updated_at DESC, id DESC
       LIMIT $4`,
      [boardId, cursor.updatedAt, cursor.id, limit]
    );
    return rows.map(mapNote);
  }

  const { rows } = await db.query(
    `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
     FROM notes
     WHERE board_id = $1::uuid
       AND is_deleted = FALSE
     ORDER BY updated_at DESC, id DESC
     LIMIT $2 OFFSET $3`,
    [boardId, limit, offset]
  );
  return rows.map(mapNote);
};

const listBoardNotesSinceVersion = async ({ client, boardId, sinceVersion, limit = 500 }) => {
  const db = resolveClient(client);
  const { rows } = await db.query(
    `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
     FROM notes
     WHERE board_id = $1::uuid
       AND version > $2
     ORDER BY version ASC
     LIMIT $3`,
    [boardId, sinceVersion, limit]
  );
  return rows.map(mapNote);
};

module.exports = {
  createNote,
  getNoteForUpdate,
  getNoteById,
  updateNoteWithExpectedVersion,
  softDeleteNoteWithExpectedVersion,
  listBoardNotes,
  listBoardNotesSinceVersion
};

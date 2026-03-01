const { pool } = require('../db/pool');

const mapCard = (row) => ({
  id: row.id,
  boardId: row.board_id,
  listId: row.list_id,
  title: row.title,
  description: row.description,
  orderIndex: row.order_index,
  version: Number(row.version),
  isDeleted: row.is_deleted,
  deletedAt: row.deleted_at,
  createdAt: row.created_at,
  updatedAt: row.updated_at
});

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const listCardsByListId = async (listId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, board_id, list_id, title, description, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM cards
     WHERE list_id = $1
       AND is_deleted = FALSE
     ORDER BY order_index ASC, created_at ASC`,
    [listId]
  );
  return rows.map(mapCard);
};

const createCard = async ({ boardId, listId, title, description, orderIndex }) => {
  const db = requirePool();
  const { rows } = await db.query(
    `INSERT INTO cards (board_id, list_id, title, description, order_index, updated_at)
     VALUES ($1, $2, $3, $4, $5, now())
     RETURNING id, board_id, list_id, title, description, order_index, version, is_deleted, deleted_at, created_at, updated_at`,
    [boardId, listId, title, description, orderIndex]
  );
  return mapCard(rows[0]);
};

const getCardById = async (cardId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, board_id, list_id, title, description, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM cards
     WHERE id = $1
       AND is_deleted = FALSE`,
    [cardId]
  );
  return rows[0] ? mapCard(rows[0]) : null;
};

const updateCard = async (cardId, patch) => {
  const db = requirePool();

  const fields = [];
  const values = [];

  if (typeof patch.title === 'string') {
    values.push(patch.title);
    fields.push(`title = $${values.length}`);
  }

  if (typeof patch.description === 'string') {
    values.push(patch.description);
    fields.push(`description = $${values.length}`);
  }

  if (typeof patch.listId === 'string') {
    values.push(patch.listId);
    fields.push(`list_id = $${values.length}`);
  }

  if (typeof patch.orderIndex === 'number' && Number.isFinite(patch.orderIndex)) {
    values.push(patch.orderIndex);
    fields.push(`order_index = $${values.length}`);
  }

  if (fields.length === 0) {
    return getCardById(cardId);
  }

  values.push(cardId);

  const { rows } = await db.query(
     `UPDATE cards
     SET ${fields.join(', ')}, version = version + 1, updated_at = now()
     WHERE id = $${values.length}
       AND is_deleted = FALSE
     RETURNING id, board_id, list_id, title, description, order_index, version, is_deleted, deleted_at, created_at, updated_at`,
    values
  );

  return rows[0] ? mapCard(rows[0]) : null;
};

module.exports = {
  listCardsByListId,
  createCard,
  getCardById,
  updateCard
};

const { pool } = require('../db/pool');

const mapList = (row) => ({
  id: row.id,
  boardId: row.board_id,
  title: row.title,
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

const listListsByBoardId = async (boardId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, board_id, title, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM lists
     WHERE board_id = $1
       AND is_deleted = FALSE
     ORDER BY order_index ASC, created_at ASC`,
    [boardId]
  );
  return rows.map(mapList);
};

const createList = async ({ boardId, title, orderIndex }) => {
  const db = requirePool();
  const { rows } = await db.query(
    `INSERT INTO lists (board_id, title, order_index, updated_at)
     VALUES ($1, $2, $3, now())
     RETURNING id, board_id, title, order_index, version, is_deleted, deleted_at, created_at, updated_at`,
    [boardId, title, orderIndex]
  );
  return mapList(rows[0]);
};

const getListById = async (listId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, board_id, title, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM lists
     WHERE id = $1
       AND is_deleted = FALSE`,
    [listId]
  );
  return rows[0] ? mapList(rows[0]) : null;
};

module.exports = {
  listListsByBoardId,
  createList,
  getListById
};

const { pool } = require('../db/pool');

const mapBoard = (row) => ({
  id: row.id,
  name: row.name,
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

const listBoardsForUser = async (userId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT b.id, b.name, b.version, b.is_deleted, b.deleted_at, b.created_at, b.updated_at
     FROM boards b
     INNER JOIN board_members bm ON bm.board_id = b.id
     WHERE bm.user_id = $1
       AND b.is_deleted = FALSE
     ORDER BY b.updated_at DESC`,
    [userId]
  );
  return rows.map(mapBoard);
};

const createBoardForUser = async ({ name, userId }) => {
  const db = requirePool();

  await db.query('BEGIN');
  try {
    const { rows } = await db.query(
      `INSERT INTO boards (name, updated_at)
       VALUES ($1, now())
       RETURNING id, name, version, is_deleted, deleted_at, created_at, updated_at`,
      [name]
    );

    const board = mapBoard(rows[0]);
    await db.query(
      `INSERT INTO board_members (board_id, user_id, role)
       VALUES ($1, $2, 'owner')`,
      [board.id, userId]
    );

    await db.query('COMMIT');
    return board;
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
};

const getBoardById = async (boardId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, name, version, is_deleted, deleted_at, created_at, updated_at
     FROM boards
     WHERE id = $1
       AND is_deleted = FALSE`,
    [boardId]
  );
  return rows[0] ? mapBoard(rows[0]) : null;
};

module.exports = {
  listBoardsForUser,
  createBoardForUser,
  getBoardById
};

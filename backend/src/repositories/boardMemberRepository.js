const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const getBoardRole = async ({ boardId, userId }) => {
  const db = requirePool();
  const { rows } = await db.query(
    'SELECT role FROM board_members WHERE board_id = $1 AND user_id = $2 LIMIT 1',
    [boardId, userId]
  );
  return rows[0]?.role || null;
};

const addBoardMember = async ({ boardId, userId, role }) => {
  const db = requirePool();

  await db.query(
    `INSERT INTO board_members (board_id, user_id, role)
     VALUES ($1, $2, $3)
     ON CONFLICT (board_id, user_id)
     DO UPDATE SET role = EXCLUDED.role`,
    [boardId, userId, role]
  );
};

const isBoardMember = async ({ boardId, userId }) => {
  const role = await getBoardRole({ boardId, userId });
  return Boolean(role);
};

const listBoardMembers = async (boardId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT bm.user_id, bm.role, bm.created_at, u.email, u.display_name
     FROM board_members bm
     INNER JOIN users u ON u.id = bm.user_id
     WHERE bm.board_id = $1
     ORDER BY bm.created_at ASC`,
    [boardId]
  );

  return rows.map((row) => ({
    userId: row.user_id,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    joinedAt: row.created_at
  }));
};

const updateBoardMemberRole = async ({ boardId, userId, role }) => {
  const db = requirePool();
  const { rowCount } = await db.query(
    'UPDATE board_members SET role = $3 WHERE board_id = $1 AND user_id = $2',
    [boardId, userId, role]
  );
  return rowCount > 0;
};

const removeBoardMember = async ({ boardId, userId }) => {
  const db = requirePool();
  const { rowCount } = await db.query(
    'DELETE FROM board_members WHERE board_id = $1 AND user_id = $2',
    [boardId, userId]
  );
  return rowCount > 0;
};

const countBoardOwners = async (boardId) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT COUNT(*)::int AS owner_count
     FROM board_members
     WHERE board_id = $1 AND role = 'owner'`,
    [boardId]
  );
  return rows[0]?.owner_count || 0;
};

module.exports = {
  getBoardRole,
  addBoardMember,
  isBoardMember,
  listBoardMembers,
  updateBoardMemberRole,
  removeBoardMember,
  countBoardOwners
};

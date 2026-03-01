const { pool } = require('../db/pool');

const mapUser = (row) => ({
  id: row.id,
  email: row.email,
  displayName: row.display_name,
  createdAt: row.created_at,
  updatedAt: row.updated_at
});

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const getUserByEmail = async (email) => {
  const db = requirePool();
  const { rows } = await db.query(
    `SELECT id, email, password_hash, display_name, created_at, updated_at
     FROM users
     WHERE email = $1`,
    [email.toLowerCase()]
  );

  if (!rows[0]) return null;

  return {
    ...mapUser(rows[0]),
    passwordHash: rows[0].password_hash
  };
};

const createUser = async ({ email, passwordHash, displayName }) => {
  const db = requirePool();
  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, display_name, updated_at)
     VALUES ($1, $2, $3, now())
     RETURNING id, email, display_name, created_at, updated_at`,
    [email.toLowerCase(), passwordHash, displayName]
  );

  return mapUser(rows[0]);
};

module.exports = {
  getUserByEmail,
  createUser
};

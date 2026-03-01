const { Pool } = require('pg');
const env = require('../config/env');

const pool = env.databaseUrl
  ? new Pool({ connectionString: env.databaseUrl })
  : null;

const checkDbHealth = async () => {
  if (!pool) {
    return { ok: true, db: 'not_configured' };
  }

  try {
    await pool.query('SELECT 1');
    return { ok: true, db: 'up' };
  } catch (_error) {
    return { ok: false, db: 'down', error: 'db_connection_failed' };
  }
};

module.exports = {
  pool,
  checkDbHealth
};

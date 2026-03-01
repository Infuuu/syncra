const fs = require('node:fs/promises');
const path = require('node:path');
const { pool } = require('./pool');

const MIGRATIONS_DIR = path.resolve(__dirname, '../../migrations');

const ensureMigrationsTable = async (db) => {
  await db.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
};

const getAppliedVersions = async (db) => {
  const { rows } = await db.query('SELECT version FROM schema_migrations');
  return new Set(rows.map((row) => row.version));
};

const listMigrationFiles = async () => {
  const files = await fs.readdir(MIGRATIONS_DIR);
  return files.filter((file) => file.endsWith('.sql')).sort();
};

const run = async () => {
  if (!pool) {
    throw new Error('DATABASE_URL is required to run migrations');
  }

  await ensureMigrationsTable(pool);
  const applied = await getAppliedVersions(pool);
  const files = await listMigrationFiles();

  for (const file of files) {
    if (applied.has(file)) {
      continue;
    }

    const migrationPath = path.resolve(MIGRATIONS_DIR, file);
    const sql = await fs.readFile(migrationPath, 'utf-8');

    await pool.query('BEGIN');
    try {
      await pool.query(sql);
      await pool.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      await pool.query('COMMIT');
      console.log(`Migration complete: ${file}`);
    } catch (error) {
      await pool.query('ROLLBACK');
      throw error;
    }
  }

  console.log('Migrations are up to date');
};

run()
  .catch((error) => {
    const message = error && error.message ? error.message : String(error);
    console.error('Migration failed:', message);
    if (error && error.code) {
      console.error('Code:', error.code);
    }
    process.exitCode = 1;
  })
  .finally(async () => {
    if (pool) {
      await pool.end();
    }
  });

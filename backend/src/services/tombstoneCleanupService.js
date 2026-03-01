const { pool } = require('../db/pool');

const MS_PER_DAY = 24 * 60 * 60 * 1000;

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const cleanupExpiredTombstones = async ({ retentionDays, now = new Date(), dryRun = false }) => {
  const parsedRetention = Number(retentionDays);
  if (!Number.isInteger(parsedRetention) || parsedRetention < 1) {
    throw new Error('retentionDays must be a positive integer');
  }

  const db = requirePool();
  const client = await db.connect();

  const cutoffDate = new Date(now.getTime() - parsedRetention * MS_PER_DAY);

  try {
    await client.query('BEGIN');

    const cardEligible = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM cards
       WHERE is_deleted = TRUE
         AND deleted_at IS NOT NULL
         AND deleted_at < $1`,
      [cutoffDate]
    );

    const listEligible = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM lists l
       WHERE l.is_deleted = TRUE
         AND l.deleted_at IS NOT NULL
         AND l.deleted_at < $1
         AND NOT EXISTS (SELECT 1 FROM cards c WHERE c.list_id = l.id)`,
      [cutoffDate]
    );

    const boardEligible = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM boards b
       WHERE b.is_deleted = TRUE
         AND b.deleted_at IS NOT NULL
         AND b.deleted_at < $1
         AND NOT EXISTS (SELECT 1 FROM lists l WHERE l.board_id = b.id)
         AND NOT EXISTS (SELECT 1 FROM cards c WHERE c.board_id = b.id)`,
      [cutoffDate]
    );

    const eligible = {
      cards: cardEligible.rows[0].count,
      lists: listEligible.rows[0].count,
      boards: boardEligible.rows[0].count
    };

    if (dryRun) {
      await client.query('ROLLBACK');
      return {
        dryRun: true,
        retentionDays: parsedRetention,
        cutoffDate: cutoffDate.toISOString(),
        eligible,
        deleted: {
          cards: 0,
          lists: 0,
          boards: 0
        }
      };
    }

    const deleteCards = await client.query(
      `DELETE FROM cards
       WHERE is_deleted = TRUE
         AND deleted_at IS NOT NULL
         AND deleted_at < $1`,
      [cutoffDate]
    );

    const deleteLists = await client.query(
      `DELETE FROM lists l
       WHERE l.is_deleted = TRUE
         AND l.deleted_at IS NOT NULL
         AND l.deleted_at < $1
         AND NOT EXISTS (SELECT 1 FROM cards c WHERE c.list_id = l.id)`,
      [cutoffDate]
    );

    const deleteBoards = await client.query(
      `DELETE FROM boards b
       WHERE b.is_deleted = TRUE
         AND b.deleted_at IS NOT NULL
         AND b.deleted_at < $1
         AND NOT EXISTS (SELECT 1 FROM lists l WHERE l.board_id = b.id)
         AND NOT EXISTS (SELECT 1 FROM cards c WHERE c.board_id = b.id)`,
      [cutoffDate]
    );

    await client.query('COMMIT');

    return {
      dryRun: false,
      retentionDays: parsedRetention,
      cutoffDate: cutoffDate.toISOString(),
      eligible,
      deleted: {
        cards: deleteCards.rowCount,
        lists: deleteLists.rowCount,
        boards: deleteBoards.rowCount
      }
    };
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_rollbackError) {
      // preserve original error
    }
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  cleanupExpiredTombstones
};

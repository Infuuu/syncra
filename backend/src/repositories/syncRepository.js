const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const mapSyncOperation = (row) => ({
  version: Number(row.version),
  boardId: row.board_id,
  actorUserId: row.actor_user_id,
  clientOperationId: row.client_operation_id,
  operationType: row.operation_type,
  entityType: row.entity_type,
  entityId: row.entity_id,
  payload: row.payload,
  createdAt: row.created_at
});

const insertSyncOperation = async ({
  boardId,
  actorUserId,
  clientOperationId,
  operationType,
  entityType,
  entityId,
  payload,
  applyCanonicalMutation
}) => {
  const db = requirePool();
  const client = await db.connect();

  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `INSERT INTO sync_operations (
         board_id,
         actor_user_id,
         client_operation_id,
         operation_type,
         entity_type,
         entity_id,
         payload
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
       ON CONFLICT (actor_user_id, client_operation_id)
       WHERE client_operation_id IS NOT NULL
       DO NOTHING
       RETURNING version, board_id, actor_user_id, client_operation_id, operation_type, entity_type, entity_id, payload, created_at`,
      [
        boardId,
        actorUserId,
        clientOperationId || null,
        operationType,
        entityType,
        entityId,
        JSON.stringify(payload || {})
      ]
    );

    if (rows[0]) {
      const mapped = mapSyncOperation(rows[0]);

      if (typeof applyCanonicalMutation === 'function') {
        await applyCanonicalMutation(client, mapped);
      }

      await client.query('COMMIT');
      return {
        status: 'applied',
        operation: mapped
      };
    }

    if (clientOperationId) {
      const existing = await client.query(
        `SELECT version, board_id, actor_user_id, client_operation_id, operation_type, entity_type, entity_id, payload, created_at
         FROM sync_operations
         WHERE actor_user_id = $1 AND client_operation_id = $2
         LIMIT 1`,
        [actorUserId, clientOperationId]
      );

      if (existing.rows[0]) {
        await client.query('COMMIT');
        return {
          status: 'duplicate',
          operation: mapSyncOperation(existing.rows[0])
        };
      }
    }

    await client.query('ROLLBACK');
    throw new Error('failed to insert sync operation');
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_rollbackError) {
      // no-op: preserve original error
    }
    throw error;
  } finally {
    client.release();
  }
};

const listOperationsForUserSinceVersion = async ({ userId, sinceVersion, boardId = null, limit = 500 }) => {
  const db = requirePool();
  const params = [userId, sinceVersion, limit];

  let boardClause = '';
  if (boardId) {
    params.push(boardId);
    boardClause = ` AND so.board_id = $${params.length}`;
  }

  const { rows } = await db.query(
    `SELECT so.version, so.board_id, so.actor_user_id, so.client_operation_id, so.operation_type,
            so.entity_type, so.entity_id, so.payload, so.created_at
     FROM sync_operations so
     INNER JOIN board_members bm ON bm.board_id = so.board_id
     WHERE bm.user_id = $1
       AND so.version > $2
       ${boardClause}
     ORDER BY so.version ASC
     LIMIT $3`,
    params
  );

  return rows.map(mapSyncOperation);
};

const getLatestVisibleVersionForUser = async ({ userId, sinceVersion = 0, boardId = null }) => {
  const db = requirePool();
  const params = [userId, sinceVersion];

  let boardClause = '';
  if (boardId) {
    params.push(boardId);
    boardClause = ` AND so.board_id = $${params.length}`;
  }

  const { rows } = await db.query(
    `SELECT COALESCE(MAX(so.version), $2::bigint)::bigint AS latest_version
     FROM sync_operations so
     INNER JOIN board_members bm ON bm.board_id = so.board_id
     WHERE bm.user_id = $1
       ${boardClause}`,
    params
  );

  return Number(rows[0]?.latest_version || sinceVersion);
};

module.exports = {
  insertSyncOperation,
  listOperationsForUserSinceVersion,
  getLatestVisibleVersionForUser
};

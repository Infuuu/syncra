const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const mapFailure = (row) => ({
  id: Number(row.id),
  actorUserId: row.actor_user_id,
  boardId: row.board_id,
  clientOperationId: row.client_operation_id,
  operationType: row.operation_type,
  entityType: row.entity_type,
  entityId: row.entity_id,
  payload: row.payload,
  statusCode: row.status_code,
  lastErrorCode: row.last_error_code,
  lastErrorMessage: row.last_error_message,
  attemptCount: row.attempt_count,
  firstFailedAt: row.first_failed_at,
  lastFailedAt: row.last_failed_at,
  resolvedAt: row.resolved_at
});

const recordSyncFailure = async ({
  actorUserId,
  boardId,
  clientOperationId,
  operationType,
  entityType,
  entityId,
  payload,
  statusCode,
  errorCode,
  errorMessage
}) => {
  const db = requirePool();

  if (clientOperationId) {
    const { rows } = await db.query(
      `INSERT INTO sync_failed_operations (
         actor_user_id,
         board_id,
         client_operation_id,
         operation_type,
         entity_type,
         entity_id,
         payload,
         status_code,
         last_error_code,
         last_error_message
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)
       ON CONFLICT (actor_user_id, client_operation_id)
       WHERE client_operation_id IS NOT NULL
       DO UPDATE SET
         board_id = EXCLUDED.board_id,
         operation_type = EXCLUDED.operation_type,
         entity_type = EXCLUDED.entity_type,
         entity_id = EXCLUDED.entity_id,
         payload = EXCLUDED.payload,
         status_code = EXCLUDED.status_code,
         last_error_code = EXCLUDED.last_error_code,
         last_error_message = EXCLUDED.last_error_message,
         attempt_count = sync_failed_operations.attempt_count + 1,
         last_failed_at = now(),
         resolved_at = NULL
       RETURNING *`,
      [
        actorUserId,
        boardId || null,
        clientOperationId,
        operationType,
        entityType,
        entityId,
        JSON.stringify(payload || {}),
        statusCode,
        errorCode || null,
        errorMessage
      ]
    );

    return mapFailure(rows[0]);
  }

  const { rows } = await db.query(
    `INSERT INTO sync_failed_operations (
       actor_user_id,
       board_id,
       operation_type,
       entity_type,
       entity_id,
       payload,
       status_code,
       last_error_code,
       last_error_message
     )
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9)
     RETURNING *`,
    [
      actorUserId,
      boardId || null,
      operationType,
      entityType,
      entityId,
      JSON.stringify(payload || {}),
      statusCode,
      errorCode || null,
      errorMessage
    ]
  );

  return mapFailure(rows[0]);
};

const resolveSyncFailureByClientOperation = async ({ actorUserId, clientOperationId }) => {
  if (!clientOperationId) return false;

  const db = requirePool();
  const { rowCount } = await db.query(
    `UPDATE sync_failed_operations
     SET resolved_at = now()
     WHERE actor_user_id = $1
       AND client_operation_id = $2
       AND resolved_at IS NULL`,
    [actorUserId, clientOperationId]
  );

  return rowCount > 0;
};

const listOpenFailuresByActor = async ({ actorUserId, boardId = null, limit = 100 }) => {
  const db = requirePool();
  const params = [actorUserId, limit];

  let boardClause = '';
  if (boardId) {
    params.push(boardId);
    boardClause = ` AND board_id = $${params.length}`;
  }

  const { rows } = await db.query(
    `SELECT *
     FROM sync_failed_operations
     WHERE actor_user_id = $1
       AND resolved_at IS NULL
       ${boardClause}
     ORDER BY last_failed_at DESC
     LIMIT $2`,
    params
  );

  return rows.map(mapFailure);
};

const getOpenFailureByIdForActor = async ({ actorUserId, failureId }) => {
  const id = Number(failureId);
  if (!Number.isInteger(id) || id < 1) return null;

  const db = requirePool();
  const { rows } = await db.query(
    `SELECT *
     FROM sync_failed_operations
     WHERE id = $1
       AND actor_user_id = $2
       AND resolved_at IS NULL
     LIMIT 1`,
    [id, actorUserId]
  );

  if (!rows[0]) return null;
  return mapFailure(rows[0]);
};

const markRetryFailureAttempt = async ({
  actorUserId,
  failureId,
  statusCode,
  errorCode,
  errorMessage
}) => {
  const id = Number(failureId);
  if (!Number.isInteger(id) || id < 1) return null;

  const db = requirePool();
  const { rows } = await db.query(
    `UPDATE sync_failed_operations
     SET status_code = $3,
         last_error_code = $4,
         last_error_message = $5,
         attempt_count = attempt_count + 1,
         last_failed_at = now(),
         resolved_at = NULL
     WHERE id = $1
       AND actor_user_id = $2
       AND resolved_at IS NULL
     RETURNING *`,
    [id, actorUserId, statusCode, errorCode || null, errorMessage]
  );

  if (!rows[0]) return null;
  return mapFailure(rows[0]);
};

const resolveSyncFailureById = async ({ actorUserId, failureId }) => {
  const id = Number(failureId);
  if (!Number.isInteger(id) || id < 1) return false;

  const db = requirePool();
  const { rowCount } = await db.query(
    `UPDATE sync_failed_operations
     SET resolved_at = now()
     WHERE id = $1
       AND actor_user_id = $2
       AND resolved_at IS NULL`,
    [id, actorUserId]
  );

  return rowCount > 0;
};

module.exports = {
  recordSyncFailure,
  resolveSyncFailureByClientOperation,
  listOpenFailuresByActor,
  getOpenFailureByIdForActor,
  markRetryFailureAttempt,
  resolveSyncFailureById
};

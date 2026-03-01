const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const mapAuditLog = (row) => ({
  id: Number(row.id),
  actorUserId: row.actor_user_id,
  boardId: row.board_id,
  eventType: row.event_type,
  entityType: row.entity_type,
  entityId: row.entity_id,
  metadata: row.metadata,
  createdAt: row.created_at
});

const createAuditLog = async ({
  client = null,
  actorUserId = null,
  boardId = null,
  eventType,
  entityType,
  entityId,
  metadata = {}
}) => {
  const db = client || requirePool();
  const { rows } = await db.query(
    `INSERT INTO audit_logs (
       actor_user_id,
       board_id,
       event_type,
       entity_type,
       entity_id,
       metadata
     )
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING *`,
    [
      actorUserId || null,
      boardId || null,
      eventType,
      entityType,
      entityId,
      JSON.stringify(metadata || {})
    ]
  );

  return mapAuditLog(rows[0]);
};

const listAuditLogsByBoard = async ({ boardId, limit = 100 }) => {
  const db = requirePool();
  const normalizedLimit = Number.isFinite(Number(limit))
    ? Math.min(Math.max(Number(limit), 1), 500)
    : 100;
  const { rows } = await db.query(
    `SELECT *
     FROM audit_logs
     WHERE board_id = $1
     ORDER BY created_at DESC, id DESC
     LIMIT $2`,
    [boardId, normalizedLimit]
  );
  return rows.map(mapAuditLog);
};

module.exports = {
  createAuditLog,
  listAuditLogsByBoard
};

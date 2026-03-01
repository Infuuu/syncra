const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { runMaintenanceCleanup } = require('../src/services/maintenanceCleanupService');

const uniqueEmail = (prefix) => `${prefix}.${Date.now()}.${Math.floor(Math.random() * 100000)}@example.com`;

const clearDb = async () => {
  await pool.query(
    'TRUNCATE TABLE refresh_tokens, audit_logs, sync_failed_operations, board_sync_state, sync_operations, board_members, cards, lists, boards, users CASCADE'
  );
};

const registerAndGetUser = async (email, displayName) => {
  const password = 'Password123';
  const registerRes = await request(app).post('/api/auth/register').send({
    email,
    password,
    displayName
  });
  assert.equal(registerRes.statusCode, 201);
  return registerRes.body.user;
};

test.before(async () => {
  assert.ok(pool, 'DATABASE_URL must be configured for integration tests');
  await clearDb();
});

test.after(async () => {
  await clearDb();
  await pool.end();
});

test('maintenance cleanup deletes expired refresh tokens, resolved failures, and old audit logs', async () => {
  await clearDb();

  const user = await registerAndGetUser(uniqueEmail('maintenance-user'), 'Maintenance User');

  await pool.query(
    `INSERT INTO refresh_tokens (
       user_id, token_hash, family_id, expires_at, revoked_at, revoke_reason
     ) VALUES
       ($1::uuid, $2, $3::uuid, now() - INTERVAL '40 days', now() - INTERVAL '35 days', 'old'),
       ($1::uuid, $4, $5::uuid, now() - INTERVAL '1 day', NULL, NULL)`,
    [
      user.id,
      `hash-old-${Date.now()}`,
      crypto.randomUUID(),
      `hash-expired-${Date.now()}`,
      crypto.randomUUID()
    ]
  );

  await pool.query(
    `INSERT INTO sync_failed_operations (
       actor_user_id,
       operation_type,
       entity_type,
       entity_id,
       payload,
       status_code,
       last_error_message,
       resolved_at,
       last_failed_at
     ) VALUES (
       $1::uuid,
       'card.updated',
       'card',
       'entity-old',
       '{}'::jsonb,
       409,
       'old conflict',
       now() - INTERVAL '45 days',
       now() - INTERVAL '45 days'
     )`,
    [user.id]
  );

  await pool.query(
    `INSERT INTO audit_logs (
       actor_user_id,
       event_type,
       entity_type,
       entity_id,
       metadata,
       created_at
     ) VALUES (
       $1::uuid,
       'auth.logged_in',
       'user',
       $1,
       '{}'::jsonb,
       now() - INTERVAL '120 days'
     )`,
    [user.id]
  );

  const dryRun = await runMaintenanceCleanup({
    dryRun: true,
    refreshTokenRetentionDays: 30,
    syncFailureRetentionDays: 30,
    auditLogRetentionDays: 90
  });
  assert.equal(dryRun.dryRun, true);
  assert.ok(dryRun.eligible.refreshTokens.expire >= 1);
  assert.ok(dryRun.eligible.refreshTokens.delete >= 1);
  assert.ok(dryRun.eligible.syncFailuresResolvedDelete >= 1);
  assert.ok(dryRun.eligible.auditLogsDelete >= 1);
  assert.equal(dryRun.affected.refreshTokensDeleted, 0);
  assert.equal(dryRun.affected.syncFailuresDeleted, 0);
  assert.equal(dryRun.affected.auditLogsDeleted, 0);

  const result = await runMaintenanceCleanup({
    dryRun: false,
    refreshTokenRetentionDays: 30,
    syncFailureRetentionDays: 30,
    auditLogRetentionDays: 90
  });
  assert.equal(result.dryRun, false);
  assert.ok(result.affected.refreshTokensExpired >= 1);
  assert.ok(result.affected.refreshTokensDeleted >= 1);
  assert.ok(result.affected.syncFailuresDeleted >= 1);
  assert.ok(result.affected.auditLogsDeleted >= 1);

  const refreshRows = await pool.query(
    `SELECT COUNT(*)::int AS count
     FROM refresh_tokens
     WHERE expires_at < now() - INTERVAL '30 days'
        OR (revoked_at IS NOT NULL AND revoked_at < now() - INTERVAL '30 days')`
  );
  assert.equal(refreshRows.rows[0].count, 0);

  const oldResolvedFailures = await pool.query(
    `SELECT COUNT(*)::int AS count
     FROM sync_failed_operations
     WHERE resolved_at IS NOT NULL
       AND resolved_at < now() - INTERVAL '30 days'`
  );
  assert.equal(oldResolvedFailures.rows[0].count, 0);

  const oldAuditRows = await pool.query(
    `SELECT COUNT(*)::int AS count
     FROM audit_logs
     WHERE created_at < now() - INTERVAL '90 days'`
  );
  assert.equal(oldAuditRows.rows[0].count, 0);
});

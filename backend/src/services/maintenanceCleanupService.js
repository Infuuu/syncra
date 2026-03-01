const { pool } = require('../db/pool');

const MS_PER_DAY = 24 * 60 * 60 * 1000;

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const parseRetention = (value, label) => {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${label} must be a positive integer`);
  }
  return parsed;
};

const runMaintenanceCleanup = async ({
  now = new Date(),
  dryRun = false,
  refreshTokenRetentionDays,
  syncFailureRetentionDays,
  auditLogRetentionDays
}) => {
  const parsedRefreshDays = parseRetention(refreshTokenRetentionDays, 'refreshTokenRetentionDays');
  const parsedSyncFailureDays = parseRetention(syncFailureRetentionDays, 'syncFailureRetentionDays');
  const parsedAuditDays = parseRetention(auditLogRetentionDays, 'auditLogRetentionDays');

  const refreshCutoff = new Date(now.getTime() - parsedRefreshDays * MS_PER_DAY);
  const syncFailureCutoff = new Date(now.getTime() - parsedSyncFailureDays * MS_PER_DAY);
  const auditCutoff = new Date(now.getTime() - parsedAuditDays * MS_PER_DAY);

  const db = requirePool();
  const client = await db.connect();

  try {
    await client.query('BEGIN');

    const refreshExpiredEligibleRes = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM refresh_tokens
       WHERE revoked_at IS NULL
         AND expires_at < $1`,
      [now]
    );

    const refreshDeleteEligibleRes = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM refresh_tokens
       WHERE (revoked_at IS NOT NULL AND revoked_at < $1)
          OR (expires_at < $1)`,
      [refreshCutoff]
    );

    const syncFailureDeleteEligibleRes = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM sync_failed_operations
       WHERE resolved_at IS NOT NULL
         AND resolved_at < $1`,
      [syncFailureCutoff]
    );

    const auditDeleteEligibleRes = await client.query(
      `SELECT COUNT(*)::int AS count
       FROM audit_logs
       WHERE created_at < $1`,
      [auditCutoff]
    );

    const eligible = {
      refreshTokens: {
        expire: refreshExpiredEligibleRes.rows[0].count,
        delete: refreshDeleteEligibleRes.rows[0].count
      },
      syncFailuresResolvedDelete: syncFailureDeleteEligibleRes.rows[0].count,
      auditLogsDelete: auditDeleteEligibleRes.rows[0].count
    };

    if (dryRun) {
      await client.query('ROLLBACK');
      return {
        dryRun: true,
        cutoffs: {
          refreshCutoff: refreshCutoff.toISOString(),
          syncFailureCutoff: syncFailureCutoff.toISOString(),
          auditCutoff: auditCutoff.toISOString()
        },
        retentionDays: {
          refreshTokenCleanup: parsedRefreshDays,
          syncFailureCleanup: parsedSyncFailureDays,
          auditCleanup: parsedAuditDays
        },
        eligible,
        affected: {
          refreshTokensExpired: 0,
          refreshTokensDeleted: 0,
          syncFailuresDeleted: 0,
          auditLogsDeleted: 0
        }
      };
    }

    const expireRefreshRes = await client.query(
      `UPDATE refresh_tokens
       SET revoked_at = now(),
           revoke_reason = COALESCE(revoke_reason, 'refresh_token_expired_cleanup')
       WHERE revoked_at IS NULL
         AND expires_at < $1`,
      [now]
    );

    const deleteRefreshRes = await client.query(
      `DELETE FROM refresh_tokens
       WHERE (revoked_at IS NOT NULL AND revoked_at < $1)
          OR (expires_at < $1)`,
      [refreshCutoff]
    );

    const deleteSyncFailuresRes = await client.query(
      `DELETE FROM sync_failed_operations
       WHERE resolved_at IS NOT NULL
         AND resolved_at < $1`,
      [syncFailureCutoff]
    );

    const deleteAuditRes = await client.query(
      `DELETE FROM audit_logs
       WHERE created_at < $1`,
      [auditCutoff]
    );

    await client.query('COMMIT');

    return {
      dryRun: false,
      cutoffs: {
        refreshCutoff: refreshCutoff.toISOString(),
        syncFailureCutoff: syncFailureCutoff.toISOString(),
        auditCutoff: auditCutoff.toISOString()
      },
      retentionDays: {
        refreshTokenCleanup: parsedRefreshDays,
        syncFailureCleanup: parsedSyncFailureDays,
        auditCleanup: parsedAuditDays
      },
      eligible,
      affected: {
        refreshTokensExpired: expireRefreshRes.rowCount,
        refreshTokensDeleted: deleteRefreshRes.rowCount,
        syncFailuresDeleted: deleteSyncFailuresRes.rowCount,
        auditLogsDeleted: deleteAuditRes.rowCount
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
  runMaintenanceCleanup
};

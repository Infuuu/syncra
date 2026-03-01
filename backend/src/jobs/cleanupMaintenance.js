const env = require('../config/env');
const { pool } = require('../db/pool');
const logger = require('../services/loggerService');
const { runMaintenanceCleanup } = require('../services/maintenanceCleanupService');

const hasArg = (name) => process.argv.includes(name);

const run = async () => {
  const dryRun = hasArg('--dry-run');

  const result = await runMaintenanceCleanup({
    dryRun,
    refreshTokenRetentionDays: env.refreshTokenCleanupRetentionDays,
    syncFailureRetentionDays: env.syncFailureRetentionDays,
    auditLogRetentionDays: env.auditLogRetentionDays
  });

  logger.info('maintenance_cleanup_completed', result);
};

run()
  .catch((error) => {
    logger.error('maintenance_cleanup_failed', {
      message: error.message
    });
    process.exitCode = 1;
  })
  .finally(async () => {
    if (pool) {
      await pool.end();
    }
  });

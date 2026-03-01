const env = require('../config/env');
const { pool } = require('../db/pool');
const logger = require('../services/loggerService');
const { cleanupExpiredTombstones } = require('../services/tombstoneCleanupService');

const hasArg = (name) => process.argv.includes(name);

const run = async () => {
  const dryRun = hasArg('--dry-run');

  const result = await cleanupExpiredTombstones({
    retentionDays: env.tombstoneRetentionDays,
    dryRun
  });

  logger.info('tombstone_cleanup_completed', result);
};

run()
  .catch((error) => {
    logger.error('tombstone_cleanup_failed', {
      message: error.message
    });
    process.exitCode = 1;
  })
  .finally(async () => {
    if (pool) {
      await pool.end();
    }
  });

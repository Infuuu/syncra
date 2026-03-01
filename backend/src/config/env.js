const dotenv = require('dotenv');

dotenv.config();

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: toNumber(process.env.PORT, 4000),
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: process.env.JWT_SECRET || 'dev-only-secret-change-me',
  accessTokenExpiresIn: process.env.ACCESS_TOKEN_EXPIRES_IN || process.env.JWT_EXPIRES_IN || '15m',
  refreshTokenTtlDays: toNumber(process.env.REFRESH_TOKEN_TTL_DAYS, 30),
  jsonBodyLimit: process.env.JSON_BODY_LIMIT || '1mb',
  authRateWindowMs: toNumber(process.env.AUTH_RATE_WINDOW_MS, 10 * 60 * 1000),
  authRateMaxRequests: toNumber(process.env.AUTH_RATE_MAX_REQUESTS, 30),
  syncRateWindowMs: toNumber(process.env.SYNC_RATE_WINDOW_MS, 60 * 1000),
  syncRateMaxRequests: toNumber(process.env.SYNC_RATE_MAX_REQUESTS, 120),
  syncBodyMaxBytes: toNumber(process.env.SYNC_BODY_MAX_BYTES, 256 * 1024),
  tombstoneRetentionDays: toNumber(process.env.TOMBSTONE_RETENTION_DAYS, 30),
  refreshTokenCleanupRetentionDays: toNumber(process.env.REFRESH_TOKEN_CLEANUP_RETENTION_DAYS, 30),
  syncFailureRetentionDays: toNumber(process.env.SYNC_FAILURE_RETENTION_DAYS, 30),
  auditLogRetentionDays: toNumber(process.env.AUDIT_LOG_RETENTION_DAYS, 90)
};

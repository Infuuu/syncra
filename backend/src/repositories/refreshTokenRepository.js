const { pool } = require('../db/pool');

const requirePool = () => {
  if (!pool) throw new Error('DATABASE_URL is required');
  return pool;
};

const mapToken = (row) => ({
  id: row.id,
  userId: row.user_id,
  tokenHash: row.token_hash,
  familyId: row.family_id,
  parentTokenId: row.parent_token_id,
  replacedByTokenId: row.replaced_by_token_id,
  issuedAt: row.issued_at,
  expiresAt: row.expires_at,
  revokedAt: row.revoked_at,
  revokeReason: row.revoke_reason
});

const createRefreshToken = async ({
  client,
  userId,
  tokenHash,
  familyId,
  expiresAt,
  parentTokenId = null
}) => {
  const db = client || requirePool();
  const { rows } = await db.query(
    `INSERT INTO refresh_tokens (
       user_id,
       token_hash,
       family_id,
       parent_token_id,
       expires_at
     )
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, tokenHash, familyId, parentTokenId, expiresAt]
  );

  return mapToken(rows[0]);
};

const getRefreshTokenByHash = async ({ client, tokenHash, forUpdate = false }) => {
  const db = client || requirePool();
  const lock = forUpdate ? ' FOR UPDATE' : '';
  const { rows } = await db.query(
    `SELECT *
     FROM refresh_tokens
     WHERE token_hash = $1
     LIMIT 1${lock}`,
    [tokenHash]
  );
  if (!rows[0]) return null;
  return mapToken(rows[0]);
};

const revokeRefreshTokenById = async ({
  client,
  tokenId,
  reason,
  replacedByTokenId = null
}) => {
  const db = client || requirePool();
  const { rowCount } = await db.query(
    `UPDATE refresh_tokens
     SET revoked_at = now(),
         revoke_reason = $2,
         replaced_by_token_id = COALESCE($3, replaced_by_token_id)
     WHERE id = $1
       AND revoked_at IS NULL`,
    [tokenId, reason, replacedByTokenId]
  );
  return rowCount > 0;
};

const revokeRefreshTokenByHash = async ({ tokenHash, reason }) => {
  const db = requirePool();
  const { rowCount } = await db.query(
    `UPDATE refresh_tokens
     SET revoked_at = now(),
         revoke_reason = $2
     WHERE token_hash = $1
       AND revoked_at IS NULL`,
    [tokenHash, reason]
  );
  return rowCount > 0;
};

const revokeFamilyTokens = async ({ client, familyId, reason }) => {
  const db = client || requirePool();
  const { rowCount } = await db.query(
    `UPDATE refresh_tokens
     SET revoked_at = now(),
         revoke_reason = $2
     WHERE family_id = $1
       AND revoked_at IS NULL`,
    [familyId, reason]
  );
  return rowCount;
};

module.exports = {
  createRefreshToken,
  getRefreshTokenByHash,
  revokeRefreshTokenById,
  revokeRefreshTokenByHash,
  revokeFamilyTokens
};

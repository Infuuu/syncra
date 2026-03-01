const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('node:crypto');

const userRepository = require('../repositories/userRepository');
const refreshTokenRepository = require('../repositories/refreshTokenRepository');
const auditLogRepository = require('../repositories/auditLogRepository');
const { pool } = require('../db/pool');
const {
  signAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  calculateRefreshTokenExpiresAt
} = require('../services/tokenService');
const { badRequest, conflict, unauthorized, serverError } = require('../utils/http');

const router = express.Router();

const getRequestMetadata = (req) => ({
  ip: req.ip || null,
  userAgent: req.header('user-agent') || null
});

const toAuthResponse = (user, accessToken, refreshToken) => ({
  user: {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  },
  token: accessToken,
  accessToken,
  refreshToken,
  tokenType: 'Bearer'
});

const issueTokenPair = async ({ user, familyId = null, parentTokenId = null, client = null }) => {
  const accessToken = signAccessToken(user);
  const refreshToken = generateRefreshToken();
  const refreshTokenHash = hashRefreshToken(refreshToken);
  const refreshFamilyId = familyId || crypto.randomUUID();

  const refreshTokenRecord = await refreshTokenRepository.createRefreshToken({
    client,
    userId: user.id,
    tokenHash: refreshTokenHash,
    familyId: refreshFamilyId,
    expiresAt: calculateRefreshTokenExpiresAt(),
    parentTokenId
  });

  return {
    accessToken,
    refreshToken,
    refreshTokenId: refreshTokenRecord.id,
    familyId: refreshFamilyId
  };
};

router.post('/register', async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  const displayName = String(req.body?.displayName || '').trim();

  if (!email) return badRequest(res, 'email is required');
  if (!password) return badRequest(res, 'password is required');
  if (!displayName) return badRequest(res, 'displayName is required');
  if (password.length < 8) return badRequest(res, 'password must be at least 8 characters');

  try {
    const existing = await userRepository.getUserByEmail(email);
    if (existing) return conflict(res, 'email already registered');

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await userRepository.createUser({ email, passwordHash, displayName });
    const { accessToken, refreshToken } = await issueTokenPair({ user });
    await auditLogRepository.createAuditLog({
      actorUserId: user.id,
      boardId: null,
      eventType: 'auth.registered',
      entityType: 'user',
      entityId: user.id,
      metadata: getRequestMetadata(req)
    });

    return res.status(201).json(toAuthResponse(user, accessToken, refreshToken));
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/login', async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');

  if (!email) return badRequest(res, 'email is required');
  if (!password) return badRequest(res, 'password is required');

  try {
    const user = await userRepository.getUserByEmail(email);
    if (!user) return unauthorized(res, 'invalid email or password');

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) return unauthorized(res, 'invalid email or password');

    const { accessToken, refreshToken } = await issueTokenPair({ user });
    await auditLogRepository.createAuditLog({
      actorUserId: user.id,
      boardId: null,
      eventType: 'auth.logged_in',
      entityType: 'user',
      entityId: user.id,
      metadata: getRequestMetadata(req)
    });
    return res.json(toAuthResponse(user, accessToken, refreshToken));
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/refresh', async (req, res) => {
  const presentedRefreshToken = String(req.body?.refreshToken || '').trim();
  if (!presentedRefreshToken) return badRequest(res, 'refreshToken is required');

  const refreshTokenHash = hashRefreshToken(presentedRefreshToken);

  if (!pool) return serverError(res, 'DATABASE_URL is required');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existing = await refreshTokenRepository.getRefreshTokenByHash({
      client,
      tokenHash: refreshTokenHash,
      forUpdate: true
    });

    if (!existing) {
      await client.query('ROLLBACK');
      return unauthorized(res, 'invalid refresh token');
    }

    if (existing.revokedAt) {
      await refreshTokenRepository.revokeFamilyTokens({
        client,
        familyId: existing.familyId,
        reason: 'refresh_token_reuse_detected'
      });
      await auditLogRepository.createAuditLog({
        client,
        actorUserId: existing.userId,
        boardId: null,
        eventType: 'auth.refresh_reuse_detected',
        entityType: 'refresh_token_family',
        entityId: existing.familyId,
        metadata: getRequestMetadata(req)
      });
      await client.query('COMMIT');
      return unauthorized(res, 'refresh token reuse detected');
    }

    if (new Date(existing.expiresAt).getTime() <= Date.now()) {
      await refreshTokenRepository.revokeRefreshTokenById({
        client,
        tokenId: existing.id,
        reason: 'refresh_token_expired'
      });
      await auditLogRepository.createAuditLog({
        client,
        actorUserId: existing.userId,
        boardId: null,
        eventType: 'auth.refresh_expired',
        entityType: 'refresh_token',
        entityId: existing.id,
        metadata: getRequestMetadata(req)
      });
      await client.query('COMMIT');
      return unauthorized(res, 'refresh token expired');
    }

    const user = await userRepository.getUserById(existing.userId);
    if (!user) {
      await refreshTokenRepository.revokeFamilyTokens({
        client,
        familyId: existing.familyId,
        reason: 'user_not_found'
      });
      await client.query('COMMIT');
      return unauthorized(res, 'invalid refresh token');
    }

    const { accessToken, refreshToken, refreshTokenId } = await issueTokenPair({
      user,
      familyId: existing.familyId,
      parentTokenId: existing.id,
      client
    });

    await refreshTokenRepository.revokeRefreshTokenById({
      client,
      tokenId: existing.id,
      reason: 'refresh_token_rotated',
      replacedByTokenId: refreshTokenId
    });
    await auditLogRepository.createAuditLog({
      client,
      actorUserId: user.id,
      boardId: null,
      eventType: 'auth.refresh_rotated',
      entityType: 'refresh_token',
      entityId: refreshTokenId,
      metadata: {
        previousTokenId: existing.id,
        familyId: existing.familyId,
        ...getRequestMetadata(req)
      }
    });
    await client.query('COMMIT');

    return res.json(toAuthResponse(user, accessToken, refreshToken));
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_rollbackError) {
      // no-op
    }
    return serverError(res, error.message);
  } finally {
    client.release();
  }
});

router.post('/logout', async (req, res) => {
  const presentedRefreshToken = String(req.body?.refreshToken || '').trim();
  if (!presentedRefreshToken) return badRequest(res, 'refreshToken is required');

  try {
    const tokenHash = hashRefreshToken(presentedRefreshToken);
    const existing = await refreshTokenRepository.getRefreshTokenByHash({
      tokenHash
    });
    const revoked = await refreshTokenRepository.revokeRefreshTokenByHash({
      tokenHash,
      reason: 'logout'
    });
    if (revoked) {
      await auditLogRepository.createAuditLog({
        actorUserId: existing?.userId || null,
        boardId: null,
        eventType: 'auth.logged_out',
        entityType: 'refresh_token',
        entityId: existing?.id || 'unknown',
        metadata: getRequestMetadata(req)
      });
    }
    return revoked ? res.status(204).send() : res.status(204).send();
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

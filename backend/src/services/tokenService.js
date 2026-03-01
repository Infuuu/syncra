const jwt = require('jsonwebtoken');
const crypto = require('node:crypto');
const env = require('../config/env');

const signAccessToken = (user) =>
  jwt.sign(
    {
      sub: user.id,
      email: user.email,
      tokenType: 'access'
    },
    env.jwtSecret,
    { expiresIn: env.accessTokenExpiresIn }
  );

const verifyAccessToken = (token) => {
  const payload = jwt.verify(token, env.jwtSecret);
  if (payload?.tokenType !== 'access') {
    throw new Error('invalid token type');
  }
  return payload;
};

const generateRefreshToken = () => crypto.randomBytes(48).toString('base64url');

const hashRefreshToken = (token) =>
  crypto.createHash('sha256').update(String(token || '')).digest('hex');

const calculateRefreshTokenExpiresAt = (issuedAt = new Date()) => {
  const expiresAt = new Date(issuedAt);
  expiresAt.setDate(expiresAt.getDate() + Math.max(1, env.refreshTokenTtlDays));
  return expiresAt;
};

module.exports = {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  calculateRefreshTokenExpiresAt
};

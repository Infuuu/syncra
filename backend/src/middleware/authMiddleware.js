const { unauthorized } = require('../utils/http');
const { verifyAuthToken } = require('../services/tokenService');

const parseBearerToken = (headerValue) => {
  if (!headerValue) return null;
  const [scheme, token] = headerValue.split(' ');
  if (scheme !== 'Bearer' || !token) return null;
  return token;
};

const requireAuth = (req, res, next) => {
  const token = parseBearerToken(req.header('authorization'));
  if (!token) return unauthorized(res, 'missing or invalid authorization header');

  try {
    const payload = verifyAuthToken(token);
    req.auth = {
      userId: payload.sub,
      email: payload.email
    };
    return next();
  } catch (_error) {
    return unauthorized(res, 'invalid or expired token');
  }
};

module.exports = {
  requireAuth
};

const createRateLimiter = ({ windowMs, maxRequests, keyFn }) => {
  const buckets = new Map();

  return (req, res, next) => {
    const now = Date.now();
    const key = keyFn ? keyFn(req) : req.ip;

    if (!key) {
      return next();
    }

    const current = buckets.get(key);
    if (!current || current.resetAt <= now) {
      buckets.set(key, {
        count: 1,
        resetAt: now + windowMs
      });
      return next();
    }

    current.count += 1;

    if (current.count > maxRequests) {
      const retryAfterSeconds = Math.max(1, Math.ceil((current.resetAt - now) / 1000));
      res.setHeader('Retry-After', String(retryAfterSeconds));
      return res.status(429).json({ error: 'rate_limit_exceeded' });
    }

    return next();
  };
};

module.exports = {
  createRateLimiter
};

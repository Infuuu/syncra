const express = require('express');
const cors = require('cors');
const env = require('./config/env');

const healthRoutes = require('./routes/healthRoutes');
const metricsRoutes = require('./routes/metricsRoutes');
const docsRoutes = require('./routes/docsRoutes');
const capabilitiesRoutes = require('./routes/capabilitiesRoutes');
const authRoutes = require('./routes/authRoutes');
const boardRoutes = require('./routes/boardRoutes');
const boardMemberRoutes = require('./routes/boardMemberRoutes');
const listRoutes = require('./routes/listRoutes');
const cardRoutes = require('./routes/cardRoutes');
const syncRoutes = require('./routes/syncRoutes');
const { requireAuth } = require('./middleware/authMiddleware');
const { createRateLimiter } = require('./middleware/rateLimitMiddleware');
const { limitRequestBodyBytes } = require('./middleware/requestGuards');
const { attachRequestId, structuredRequestLogger } = require('./middleware/requestContextMiddleware');

const app = express();
app.locals.broadcastSyncOperation = () => {};

app.use(cors());
app.use(attachRequestId);
app.use(structuredRequestLogger);
app.use(express.json({ limit: env.jsonBodyLimit }));

const authRateLimiter = createRateLimiter({
  windowMs: env.authRateWindowMs,
  maxRequests: env.authRateMaxRequests,
  keyFn: (req) => req.ip
});

const syncRateLimiter = createRateLimiter({
  windowMs: env.syncRateWindowMs,
  maxRequests: env.syncRateMaxRequests,
  keyFn: (req) => req.auth?.userId || req.ip
});

app.get('/', (_req, res) => {
  res.json({
    service: 'syncra-backend',
    status: 'running'
  });
});

app.use('/health', healthRoutes);
app.use('/metrics', metricsRoutes);
app.use('/', docsRoutes);
app.use('/api/capabilities', capabilitiesRoutes);
app.use('/api/auth', authRateLimiter, authRoutes);
app.use('/api/boards', requireAuth, boardRoutes);
app.use('/api/boards/:boardId/members', requireAuth, boardMemberRoutes);
app.use('/api/lists', requireAuth, listRoutes);
app.use('/api/cards', requireAuth, cardRoutes);
app.use('/api/sync', requireAuth, syncRateLimiter, limitRequestBodyBytes(env.syncBodyMaxBytes), syncRoutes);

app.use((error, _req, res, next) => {
  if (error && error.type === 'entity.too.large') {
    return res.status(413).json({ error: 'payload_too_large' });
  }

  if (error) {
    return res.status(400).json({ error: 'invalid_json_payload' });
  }

  return next();
});

app.use((req, res) => {
  res.status(404).json({ error: `route not found: ${req.method} ${req.path}` });
});

module.exports = app;

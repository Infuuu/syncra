const { randomUUID } = require('node:crypto');
const metricsService = require('../services/metricsService');
const logger = require('../services/loggerService');

const requestIdHeader = 'x-request-id';

const attachRequestId = (req, res, next) => {
  const incoming = req.header(requestIdHeader);
  const requestId = incoming && incoming.trim() ? incoming.trim() : randomUUID();

  req.requestId = requestId;
  res.setHeader(requestIdHeader, requestId);
  return next();
};

const structuredRequestLogger = (req, res, next) => {
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const durationMs = Number(end - start) / 1_000_000;

    const routePath = req.route?.path
      ? `${req.baseUrl || ''}${req.route.path}`
      : req.path || req.originalUrl || 'unknown';

    metricsService.observeHttpRequest({
      method: req.method,
      routePath,
      statusCode: res.statusCode,
      durationMs
    });

    logger.info('http_request_completed', {
      requestId: req.requestId,
      method: req.method,
      path: req.originalUrl || req.url,
      statusCode: res.statusCode,
      durationMs: Number(durationMs.toFixed(3)),
      userId: req.auth?.userId || null,
      ip: req.ip
    });
  });

  return next();
};

module.exports = {
  attachRequestId,
  structuredRequestLogger
};

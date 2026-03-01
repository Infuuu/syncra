const express = require('express');
const metricsService = require('../services/metricsService');

const router = express.Router();

router.get('/', (_req, res) => {
  res.json({
    uptimeSeconds: Number(process.uptime().toFixed(3)),
    counters: metricsService.getSnapshot()
  });
});

router.get('/prometheus', (_req, res) => {
  const counters = metricsService.getSnapshot();
  const uptimeSeconds = Number(process.uptime().toFixed(3));

  const lines = [
    '# HELP syncra_uptime_seconds Process uptime in seconds.',
    '# TYPE syncra_uptime_seconds gauge',
    `syncra_uptime_seconds ${uptimeSeconds}`,
    '# HELP syncra_http_requests_total Total HTTP requests completed.',
    '# TYPE syncra_http_requests_total counter',
    `syncra_http_requests_total ${counters.httpRequestsTotal}`,
    '# HELP syncra_http_2xx_total Total 2xx HTTP responses.',
    '# TYPE syncra_http_2xx_total counter',
    `syncra_http_2xx_total ${counters.http2xxTotal}`,
    '# HELP syncra_http_4xx_total Total 4xx HTTP responses.',
    '# TYPE syncra_http_4xx_total counter',
    `syncra_http_4xx_total ${counters.http4xxTotal}`,
    '# HELP syncra_http_5xx_total Total 5xx HTTP responses.',
    '# TYPE syncra_http_5xx_total counter',
    `syncra_http_5xx_total ${counters.http5xxTotal}`,
    '# HELP syncra_rate_limit_exceeded_total Total requests blocked by rate limiting.',
    '# TYPE syncra_rate_limit_exceeded_total counter',
    `syncra_rate_limit_exceeded_total ${counters.rateLimitExceededTotal}`,
    '# HELP syncra_sync_push_conflicts_total Total sync push conflicts (409).',
    '# TYPE syncra_sync_push_conflicts_total counter',
    `syncra_sync_push_conflicts_total ${counters.syncPushConflictsTotal}`
  ];

  res.setHeader('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
  res.status(200).send(`${lines.join('\n')}\n`);
});

module.exports = router;

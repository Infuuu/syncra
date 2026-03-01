const express = require('express');
const metricsService = require('../services/metricsService');

const router = express.Router();

const escapePromLabel = (value) => String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
const toLabelString = (labels) =>
  Object.entries(labels || {})
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}="${escapePromLabel(value)}"`)
    .join(',');

router.get('/', (_req, res) => {
  res.json({
    uptimeSeconds: Number(process.uptime().toFixed(3)),
    counters: metricsService.getSnapshot(),
    labeledCounters: metricsService.getLabeledCounterSnapshot(),
    histograms: {
      httpRequestDurationMsByRoute: metricsService.getRequestDurationSnapshot()
    }
  });
});

router.get('/prometheus', (_req, res) => {
  const counters = metricsService.getSnapshot();
  const labeledCounters = metricsService.getLabeledCounterSnapshot();
  const requestDuration = metricsService.getRequestDurationSnapshot();
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

  lines.push('# HELP syncra_http_requests_by_route_total Total HTTP requests by route labels.');
  lines.push('# TYPE syncra_http_requests_by_route_total counter');
  for (const row of labeledCounters.httpRequestsByRouteTotal || []) {
    const labelString = toLabelString(row.labels);
    lines.push(`syncra_http_requests_by_route_total{${labelString}} ${row.value}`);
  }

  lines.push('# HELP syncra_sync_push_errors_total Total sync push errors by reason/status.');
  lines.push('# TYPE syncra_sync_push_errors_total counter');
  for (const row of labeledCounters.syncPushErrorsTotal || []) {
    const labelString = toLabelString(row.labels);
    lines.push(`syncra_sync_push_errors_total{${labelString}} ${row.value}`);
  }

  lines.push('# HELP syncra_http_request_duration_ms HTTP request duration in milliseconds by route labels.');
  lines.push('# TYPE syncra_http_request_duration_ms histogram');
  for (const series of requestDuration) {
    const baseLabels = series.labels || {};
    for (const bucket of series.buckets) {
      const labelString = toLabelString({ ...baseLabels, le: bucket.le });
      lines.push(`syncra_http_request_duration_ms_bucket{${labelString}} ${bucket.value}`);
    }
    const infLabelString = toLabelString({ ...baseLabels, le: '+Inf' });
    lines.push(`syncra_http_request_duration_ms_bucket{${infLabelString}} ${series.count}`);
    const sumLabels = toLabelString(baseLabels);
    lines.push(`syncra_http_request_duration_ms_sum{${sumLabels}} ${series.sumMs}`);
    lines.push(`syncra_http_request_duration_ms_count{${sumLabels}} ${series.count}`);
  }

  res.setHeader('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
  res.status(200).send(`${lines.join('\n')}\n`);
});

module.exports = router;

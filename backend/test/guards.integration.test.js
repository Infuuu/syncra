const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const request = require('supertest');

const { createRateLimiter } = require('../src/middleware/rateLimitMiddleware');
const { limitRequestBodyBytes } = require('../src/middleware/requestGuards');
const app = require('../src/app');

test('rate limiter returns 429 after limit is exceeded', async () => {
  const app = express();
  app.use(express.json());

  app.use(
    '/limited',
    createRateLimiter({
      windowMs: 60_000,
      maxRequests: 2,
      keyFn: (req) => req.ip
    })
  );

  app.post('/limited', (_req, res) => res.json({ ok: true }));

  const one = await request(app).post('/limited').send({});
  const two = await request(app).post('/limited').send({});
  const three = await request(app).post('/limited').send({});

  assert.equal(one.statusCode, 200);
  assert.equal(two.statusCode, 200);
  assert.equal(three.statusCode, 429);
  assert.equal(three.body.error, 'rate_limit_exceeded');
});

test('request guard returns 413 for oversized request body', async () => {
  const app = express();
  app.use(express.json());
  app.use('/guarded', limitRequestBodyBytes(40));
  app.post('/guarded', (_req, res) => res.json({ ok: true }));

  const ok = await request(app).post('/guarded').send({ x: 'short' });
  const tooLarge = await request(app).post('/guarded').send({ x: 'this payload is definitely larger than forty bytes' });

  assert.equal(ok.statusCode, 200);
  assert.equal(tooLarge.statusCode, 413);
  assert.equal(tooLarge.body.error, 'payload_too_large');
});

test('request id header is attached to responses', async () => {
  const app = express();
  const { attachRequestId } = require('../src/middleware/requestContextMiddleware');
  app.use(attachRequestId);
  app.get('/ping', (_req, res) => res.json({ ok: true }));

  const res = await request(app).get('/ping');
  assert.equal(res.statusCode, 200);
  assert.ok(typeof res.headers['x-request-id'] === 'string');
  assert.ok(res.headers['x-request-id'].length > 0);
});

test('metrics endpoint exposes counters snapshot', async () => {
  const res = await request(app).get('/metrics');
  assert.equal(res.statusCode, 200);
  assert.ok(typeof res.body.uptimeSeconds === 'number');
  assert.ok(typeof res.body.counters.httpRequestsTotal === 'number');
  assert.ok(typeof res.body.counters.syncPushConflictsTotal === 'number');
});

test('prometheus metrics endpoint exposes text format counters', async () => {
  const res = await request(app).get('/metrics/prometheus');
  assert.equal(res.statusCode, 200);
  assert.ok(res.headers['content-type'].includes('text/plain'));
  assert.ok(res.text.includes('syncra_uptime_seconds'));
  assert.ok(res.text.includes('syncra_http_requests_total'));
  assert.ok(res.text.includes('syncra_sync_push_conflicts_total'));
});

test('auth register validates email format', async () => {
  const res = await request(app).post('/api/auth/register').send({
    email: 'invalid-email',
    password: 'Password123',
    displayName: 'Invalid Email'
  });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'email must be a valid email address');
});

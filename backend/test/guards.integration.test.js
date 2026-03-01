const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const request = require('supertest');

const { createRateLimiter } = require('../src/middleware/rateLimitMiddleware');
const { limitRequestBodyBytes } = require('../src/middleware/requestGuards');

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

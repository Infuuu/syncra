const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');

const uniqueEmail = (prefix) => `${prefix}.${Date.now()}.${Math.floor(Math.random() * 100000)}@example.com`;

const clearDb = async () => {
  await pool.query(
    'TRUNCATE TABLE refresh_tokens, board_sync_state, sync_failed_operations, sync_operations, board_members, cards, lists, boards, users CASCADE'
  );
};

test.before(async () => {
  assert.ok(pool, 'DATABASE_URL must be configured for integration tests');
  await clearDb();
});

test.after(async () => {
  await clearDb();
  await pool.end();
});

test('auth refresh flow rotates refresh token and revokes family on reuse', async () => {
  await clearDb();

  const email = uniqueEmail('auth-refresh');
  const password = 'Password123';
  const registerRes = await request(app).post('/api/auth/register').send({
    email,
    password,
    displayName: 'Refresh User'
  });

  assert.equal(registerRes.statusCode, 201);
  assert.ok(registerRes.body.accessToken);
  assert.ok(registerRes.body.refreshToken);
  assert.equal(registerRes.body.token, registerRes.body.accessToken);

  const firstRefresh = registerRes.body.refreshToken;
  const firstAccess = registerRes.body.accessToken;

  const boardViaFirstAccess = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${firstAccess}`)
    .send({ name: 'Refresh Board 1' });
  assert.equal(boardViaFirstAccess.statusCode, 201);

  const refreshRes = await request(app).post('/api/auth/refresh').send({
    refreshToken: firstRefresh
  });
  assert.equal(refreshRes.statusCode, 200);
  assert.ok(refreshRes.body.accessToken);
  assert.ok(refreshRes.body.refreshToken);
  assert.notEqual(refreshRes.body.refreshToken, firstRefresh);

  const secondAccess = refreshRes.body.accessToken;
  const secondRefresh = refreshRes.body.refreshToken;

  const boardViaSecondAccess = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${secondAccess}`)
    .send({ name: 'Refresh Board 2' });
  assert.equal(boardViaSecondAccess.statusCode, 201);

  const reuseDetected = await request(app).post('/api/auth/refresh').send({
    refreshToken: firstRefresh
  });
  assert.equal(reuseDetected.statusCode, 401);
  assert.equal(reuseDetected.body.error, 'refresh token reuse detected');

  const familyRevoked = await request(app).post('/api/auth/refresh').send({
    refreshToken: secondRefresh
  });
  assert.equal(familyRevoked.statusCode, 401);
});

test('auth logout revokes refresh token', async () => {
  await clearDb();

  const email = uniqueEmail('auth-logout');
  const password = 'Password123';
  const loginRegister = await request(app).post('/api/auth/register').send({
    email,
    password,
    displayName: 'Logout User'
  });
  assert.equal(loginRegister.statusCode, 201);

  const refreshToken = loginRegister.body.refreshToken;
  assert.ok(refreshToken);

  const logoutRes = await request(app).post('/api/auth/logout').send({ refreshToken });
  assert.equal(logoutRes.statusCode, 204);

  const refreshAfterLogout = await request(app).post('/api/auth/refresh').send({ refreshToken });
  assert.equal(refreshAfterLogout.statusCode, 401);
});


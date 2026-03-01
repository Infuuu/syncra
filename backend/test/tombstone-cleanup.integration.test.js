const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { cleanupExpiredTombstones } = require('../src/services/tombstoneCleanupService');

const uniqueEmail = (prefix) => `${prefix}.${Date.now()}.${Math.floor(Math.random() * 100000)}@example.com`;

const clearDb = async () => {
  await pool.query('TRUNCATE TABLE board_sync_state, sync_operations, board_members, notes, cards, lists, boards, users CASCADE');
};

const registerAndGetToken = async (email, displayName) => {
  const password = 'Password123';
  const registerRes = await request(app).post('/api/auth/register').send({
    email,
    password,
    displayName
  });

  if (registerRes.statusCode === 201) {
    return registerRes.body.token;
  }

  const loginRes = await request(app).post('/api/auth/login').send({ email, password });
  assert.equal(loginRes.statusCode, 200, `login failed for ${email}`);
  return loginRes.body.token;
};

test.before(async () => {
  assert.ok(pool, 'DATABASE_URL must be configured for integration tests');
  await clearDb();
});

test.after(async () => {
  await clearDb();
  await pool.end();
});

test('cleanupExpiredTombstones hard-deletes expired tombstones', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('cleanup-owner'), 'Cleanup Owner');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Cleanup Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const listRes = await request(app)
    .post('/api/lists')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ boardId, title: 'Cleanup List', orderIndex: 0 });
  assert.equal(listRes.statusCode, 201);
  const listId = listRes.body.id;

  const cardRes = await request(app)
    .post('/api/cards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ boardId, listId, title: 'Cleanup Card', description: '', orderIndex: 0 });
  assert.equal(cardRes.statusCode, 201);
  const cardId = cardRes.body.id;

  const noteId = '99999999-9999-4999-8999-999999999999';
  const noteCreateRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-op-note-create',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: noteId,
          payload: {
            title: 'Cleanup Note',
            content: {
              type: 'doc',
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'cleanup' }] }]
            }
          }
        }
      ]
    });
  assert.equal(noteCreateRes.statusCode, 201);

  const deleteCardRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-op-card-del',
          boardId,
          operationType: 'card.deleted',
          entityType: 'card',
          entityId: cardId,
          payload: { expectedVersion: 1 }
        }
      ]
    });
  assert.equal(deleteCardRes.statusCode, 201);

  const deleteListRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-op-list-del',
          boardId,
          operationType: 'list.deleted',
          entityType: 'list',
          entityId: listId,
          payload: { expectedVersion: 1 }
        }
      ]
    });
  assert.equal(deleteListRes.statusCode, 201);

  const deleteNoteRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-op-note-del',
          boardId,
          operationType: 'note.deleted',
          entityType: 'note',
          entityId: noteId,
          payload: { expectedVersion: 1 }
        }
      ]
    });
  assert.equal(deleteNoteRes.statusCode, 201);

  const deleteBoardRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-op-board-del',
          boardId,
          operationType: 'board.deleted',
          entityType: 'board',
          entityId: boardId,
          payload: { expectedVersion: 1 }
        }
      ]
    });
  assert.equal(deleteBoardRes.statusCode, 201);

  await pool.query(
    "UPDATE cards SET deleted_at = now() - INTERVAL '45 days' WHERE id = $1::uuid",
    [cardId]
  );

  await pool.query(
    "UPDATE lists SET deleted_at = now() - INTERVAL '45 days' WHERE id = $1::uuid",
    [listId]
  );

  await pool.query(
    "UPDATE notes SET deleted_at = now() - INTERVAL '45 days' WHERE id = $1::uuid",
    [noteId]
  );

  await pool.query(
    "UPDATE boards SET deleted_at = now() - INTERVAL '45 days' WHERE id = $1::uuid",
    [boardId]
  );

  const cleanupResult = await cleanupExpiredTombstones({ retentionDays: 30 });
  assert.equal(cleanupResult.dryRun, false);
  assert.ok(cleanupResult.deleted.cards >= 1);
  assert.ok(cleanupResult.deleted.notes >= 1);
  assert.ok(cleanupResult.deleted.lists >= 1);
  assert.ok(cleanupResult.deleted.boards >= 1);

  const boardCheck = await pool.query('SELECT 1 FROM boards WHERE id = $1::uuid', [boardId]);
  const listCheck = await pool.query('SELECT 1 FROM lists WHERE id = $1::uuid', [listId]);
  const cardCheck = await pool.query('SELECT 1 FROM cards WHERE id = $1::uuid', [cardId]);
  const noteCheck = await pool.query('SELECT 1 FROM notes WHERE id = $1::uuid', [noteId]);

  assert.equal(boardCheck.rowCount, 0);
  assert.equal(listCheck.rowCount, 0);
  assert.equal(cardCheck.rowCount, 0);
  assert.equal(noteCheck.rowCount, 0);
});

test('cleanupExpiredTombstones dry-run does not delete data', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('cleanup-owner-dry'), 'Cleanup Owner Dry');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Dry Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'cleanup-dry-board-del',
          boardId,
          operationType: 'board.deleted',
          entityType: 'board',
          entityId: boardId,
          payload: { expectedVersion: 1 }
        }
      ]
    });

  await pool.query(
    "UPDATE boards SET deleted_at = now() - INTERVAL '45 days' WHERE id = $1::uuid",
    [boardId]
  );

  const result = await cleanupExpiredTombstones({ retentionDays: 30, dryRun: true });
  assert.equal(result.dryRun, true);
  assert.ok(result.eligible.boards >= 1);
  assert.equal(result.deleted.boards, 0);

  const boardCheck = await pool.query('SELECT is_deleted FROM boards WHERE id = $1::uuid', [boardId]);
  assert.equal(boardCheck.rowCount, 1);
  assert.equal(boardCheck.rows[0].is_deleted, true);
});

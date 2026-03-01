const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const request = require('supertest');
const WebSocket = require('ws');

const app = require('../src/app');
const env = require('../src/config/env');
const { pool } = require('../src/db/pool');
const { setupWebSocket } = require('../src/realtime/ws');

const uniqueEmail = (prefix) => `${prefix}.${Date.now()}.${Math.floor(Math.random() * 100000)}@example.com`;

const clearDb = async () => {
  await pool.query(
    'TRUNCATE TABLE sync_operations, sync_failed_operations, board_sync_state, board_members, notes, cards, lists, audit_logs, refresh_tokens, boards, users CASCADE'
  );
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

const startHttpAndWsServer = async () =>
  new Promise((resolve, reject) => {
    const server = http.createServer(app);
    const { broadcastSyncOperation } = setupWebSocket(server);
    app.locals.broadcastSyncOperation = broadcastSyncOperation;

    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({
        server,
        baseUrl: `http://127.0.0.1:${address.port}`,
        wsUrl: `ws://127.0.0.1:${address.port}`
      });
    });

    server.on('error', reject);
  });

const stopServer = async (server) =>
  new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) return reject(error);
      return resolve();
    });
  });

const waitForWsMessage = (ws, predicate, timeoutMs = 6000) =>
  new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      cleanup();
      reject(new Error('timeout waiting for websocket message'));
    }, timeoutMs);

    const onMessage = (raw) => {
      let parsed;
      try {
        parsed = JSON.parse(raw.toString());
      } catch (_error) {
        return;
      }

      if (!predicate(parsed)) return;
      cleanup();
      resolve(parsed);
    };

    const onError = (error) => {
      cleanup();
      reject(error);
    };

    const cleanup = () => {
      clearTimeout(timeout);
      ws.off('message', onMessage);
      ws.off('error', onError);
    };

    ws.on('message', onMessage);
    ws.on('error', onError);
  });

test.before(async () => {
  assert.ok(pool, 'DATABASE_URL must be configured for integration tests');
  await clearDb();
});

test.after(async () => {
  await clearDb();
  await pool.end();
});

test('Note sync lifecycle: create/update/conflict/delete plus board notes read endpoint', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('notes-owner'), 'Notes Owner');
  const editorEmail = uniqueEmail('notes-editor');
  const editorToken = await registerAndGetToken(editorEmail, 'Notes Editor');
  const viewerEmail = uniqueEmail('notes-viewer');
  const viewerToken = await registerAndGetToken(viewerEmail, 'Notes Viewer');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Notes Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const addEditorRes = await request(app)
    .post(`/api/boards/${boardId}/members`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ email: editorEmail, role: 'editor' });
  assert.equal(addEditorRes.statusCode, 201);

  const addViewerRes = await request(app)
    .post(`/api/boards/${boardId}/members`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ email: viewerEmail, role: 'viewer' });
  assert.equal(addViewerRes.statusCode, 201);

  const noteId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const createPayload = {
    title: 'Initial note',
    content: {
      type: 'doc',
      content: [{ type: 'paragraph', content: [{ type: 'text', text: 'hello' }] }]
    }
  };

  const createRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'note-op-create-1',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: noteId,
          payload: createPayload
        }
      ]
    });
  assert.equal(createRes.statusCode, 201);
  assert.equal(createRes.body.items[0].entityType, 'note');

  const listRes = await request(app)
    .get(`/api/boards/${boardId}/notes`)
    .set('Authorization', `Bearer ${viewerToken}`);
  assert.equal(listRes.statusCode, 200);
  assert.equal(listRes.body.items.length, 1);
  assert.equal(listRes.body.items[0].id, noteId);
  assert.equal(listRes.body.items[0].version, 1);

  const updateRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'note-op-update-1',
          boardId,
          operationType: 'note.updated',
          entityType: 'note',
          entityId: noteId,
          payload: {
            expectedVersion: 1,
            title: 'Updated note',
            content: {
              type: 'doc',
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'updated' }] }]
            }
          }
        }
      ]
    });
  assert.equal(updateRes.statusCode, 201);

  const staleRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'note-op-update-stale',
          boardId,
          operationType: 'note.updated',
          entityType: 'note',
          entityId: noteId,
          payload: {
            expectedVersion: 1,
            title: 'Stale update',
            content: { type: 'doc', content: [] }
          }
        }
      ]
    });
  assert.equal(staleRes.statusCode, 409);
  assert.equal(staleRes.body.errorCode, 'version_conflict');
  assert.equal(staleRes.body.conflict.serverSnapshot.entityType, 'note');
  assert.equal(staleRes.body.conflict.serverSnapshot.entity.version, 2);

  const pullRes = await request(app)
    .get('/api/sync/pull')
    .set('Authorization', `Bearer ${viewerToken}`)
    .query({ sinceVersion: 0, boardId });
  assert.equal(pullRes.statusCode, 200);
  const noteOps = pullRes.body.items.filter((item) => item.entityType === 'note');
  assert.ok(noteOps.some((item) => item.operationType === 'note.created'));
  assert.ok(noteOps.some((item) => item.operationType === 'note.updated'));

  const deleteRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'note-op-delete-1',
          boardId,
          operationType: 'note.deleted',
          entityType: 'note',
          entityId: noteId,
          payload: {
            expectedVersion: 2
          }
        }
      ]
    });
  assert.equal(deleteRes.statusCode, 201);

  const listAfterDeleteRes = await request(app)
    .get(`/api/boards/${boardId}/notes`)
    .set('Authorization', `Bearer ${viewerToken}`);
  assert.equal(listAfterDeleteRes.statusCode, 200);
  assert.equal(listAfterDeleteRes.body.items.length, 0);

  const metricsRes = await request(app).get('/metrics');
  assert.equal(metricsRes.statusCode, 200);
  assert.ok(metricsRes.body.counters.syncNoteConflictTotal >= 1);
});

test('WebSocket board channel broadcasts applied note operations', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('ws-note-owner'), 'WS Owner');
  const viewerEmail = uniqueEmail('ws-note-viewer');
  const viewerToken = await registerAndGetToken(viewerEmail, 'WS Viewer');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'WS Notes Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const addViewerRes = await request(app)
    .post(`/api/boards/${boardId}/members`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ email: viewerEmail, role: 'viewer' });
  assert.equal(addViewerRes.statusCode, 201);

  const { server, wsUrl } = await startHttpAndWsServer();
  const ws = new WebSocket(`${wsUrl}?token=${viewerToken}`);

  try {
    await waitForWsMessage(ws, (message) => message.type === 'welcome');

    ws.send(
      JSON.stringify({
        type: 'subscribe_board',
        boardId
      })
    );
    await waitForWsMessage(ws, (message) => message.type === 'subscribed_board' && message.boardId === boardId);

    const broadcastPromise = waitForWsMessage(
      ws,
      (message) =>
        message.type === 'sync.operation.applied' &&
        message.data?.entityType === 'note' &&
        message.data?.operationType === 'note.created',
      8000
    );

    const pushRes = await request(app)
      .post('/api/sync/push')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        operations: [
          {
            clientOperationId: 'ws-note-create-op',
            boardId,
            operationType: 'note.created',
            entityType: 'note',
            entityId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            payload: {
              title: 'WS note',
              content: {
                type: 'doc',
                content: [{ type: 'paragraph', content: [{ type: 'text', text: 'broadcast' }] }]
              }
            }
          }
        ]
      });
    assert.equal(pushRes.statusCode, 201);

    const broadcastMessage = await broadcastPromise;

    assert.equal(broadcastMessage.data.boardId, boardId);
  } finally {
    ws.close();
    await stopServer(server);
  }
});

test('Board notes endpoint supports cursor pagination', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('cursor-owner'), 'Cursor Owner');
  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Cursor Notes Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const noteIds = [
    '10000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003'
  ];

  for (let idx = 0; idx < noteIds.length; idx += 1) {
    const createRes = await request(app)
      .post('/api/sync/push')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        operations: [
          {
            clientOperationId: `cursor-note-create-${idx}`,
            boardId,
            operationType: 'note.created',
            entityType: 'note',
            entityId: noteIds[idx],
            payload: {
              title: `Note ${idx + 1}`,
              content: { type: 'doc', content: [{ type: 'paragraph', content: [] }] }
            }
          }
        ]
      });
    assert.equal(createRes.statusCode, 201);
  }

  // Force deterministic ordering for pagination validation.
  await pool.query(
    `UPDATE notes
     SET updated_at = CASE id
       WHEN $1::uuid THEN now() - INTERVAL '1 minute'
       WHEN $2::uuid THEN now() - INTERVAL '2 minute'
       WHEN $3::uuid THEN now() - INTERVAL '3 minute'
       ELSE updated_at
     END
     WHERE id IN ($1::uuid, $2::uuid, $3::uuid)`,
    noteIds
  );

  const page1Res = await request(app)
    .get(`/api/boards/${boardId}/notes`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .query({ limit: 2 });
  assert.equal(page1Res.statusCode, 200);
  assert.equal(page1Res.body.items.length, 2);
  assert.ok(page1Res.body.pagination.nextCursor);

  const page1Ids = page1Res.body.items.map((item) => item.id);
  const page2Res = await request(app)
    .get(`/api/boards/${boardId}/notes`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .query({ limit: 2, cursor: page1Res.body.pagination.nextCursor });
  assert.equal(page2Res.statusCode, 200);
  assert.equal(page2Res.body.items.length, 1);
  assert.equal(page2Res.body.pagination.nextCursor, null);
  assert.ok(!page1Ids.includes(page2Res.body.items[0].id));
});

test('Notes feature flag disables note sync and note read endpoints', async () => {
  await clearDb();
  const originalNotesEnabled = env.notesEnabled;

  try {
    env.notesEnabled = false;

    const ownerToken = await registerAndGetToken(uniqueEmail('flag-owner'), 'Flag Owner');
    const boardRes = await request(app)
      .post('/api/boards')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'Feature Flag Board' });
    assert.equal(boardRes.statusCode, 201);
    const boardId = boardRes.body.id;

    const listNotesRes = await request(app)
      .get(`/api/boards/${boardId}/notes`)
      .set('Authorization', `Bearer ${ownerToken}`);
    assert.equal(listNotesRes.statusCode, 404);

    const noteCreateRes = await request(app)
      .post('/api/sync/push')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        operations: [
          {
            clientOperationId: 'flag-note-op-create',
            boardId,
            operationType: 'note.created',
            entityType: 'note',
            entityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            payload: {
              title: 'Blocked note',
              content: { type: 'doc', content: [] }
            }
          }
        ]
      });
    assert.equal(noteCreateRes.statusCode, 400);
    assert.equal(noteCreateRes.body.error, 'notes feature is disabled');
    assert.equal(noteCreateRes.body.errorCode, 'notes_feature_disabled');
  } finally {
    env.notesEnabled = originalNotesEnabled;
  }
});

test('Note sync rejects malformed rich text payloads', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('schema-owner'), 'Schema Owner');
  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Schema Notes Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const badTypeRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'schema-note-bad-type',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          payload: {
            title: 'Bad',
            content: { type: 'paragraph', content: [] }
          }
        }
      ]
    });
  assert.equal(badTypeRes.statusCode, 400);
  assert.equal(badTypeRes.body.error, 'payload.content.type must be "doc"');
  assert.equal(badTypeRes.body.errorCode, 'note_content_invalid');

  const badContentArrayRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'schema-note-bad-content-array',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          payload: {
            title: 'Bad 2',
            content: { type: 'doc', content: {} }
          }
        }
      ]
    });
  assert.equal(badContentArrayRes.statusCode, 400);
  assert.equal(badContentArrayRes.body.error, 'payload.content.content must be an array');
  assert.equal(badContentArrayRes.body.errorCode, 'note_content_invalid');
});

test('Note sync enforces schemaVersion compatibility', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('version-owner'), 'Version Owner');
  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Version Notes Board' });
  assert.equal(boardRes.statusCode, 201);
  const boardId = boardRes.body.id;

  const explicitCompatibleRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'schema-version-compatible',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: '12121212-1212-4121-8121-121212121212',
          payload: {
            schemaVersion: env.noteDocSchemaVersion,
            title: 'Version OK',
            content: { type: 'doc', content: [] }
          }
        }
      ]
    });
  assert.equal(explicitCompatibleRes.statusCode, 201);

  const incompatibleVersionRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'schema-version-incompatible',
          boardId,
          operationType: 'note.created',
          entityType: 'note',
          entityId: '13131313-1313-4131-8131-131313131313',
          payload: {
            schemaVersion: env.noteDocSchemaVersion + 1,
            title: 'Version Bad',
            content: { type: 'doc', content: [] }
          }
        }
      ]
    });
  assert.equal(incompatibleVersionRes.statusCode, 400);
  assert.equal(
    incompatibleVersionRes.body.error,
    `payload.schemaVersion ${env.noteDocSchemaVersion + 1} is not supported; expected ${env.noteDocSchemaVersion}`
  );
  assert.equal(incompatibleVersionRes.body.errorCode, 'note_schema_version_unsupported');
});

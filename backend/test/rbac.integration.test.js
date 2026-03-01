const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const request = require('supertest');
const WebSocket = require('ws');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { setupWebSocket } = require('../src/realtime/ws');

const uniqueEmail = (prefix) => `${prefix}.${Date.now()}.${Math.floor(Math.random() * 100000)}@example.com`;

const clearDb = async () => {
  await pool.query('TRUNCATE TABLE sync_operations, board_members, cards, lists, boards, users CASCADE');
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

test('RBAC matrix: viewer/editor/owner access and member constraints', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('owner'), 'Owner');
  const editorEmail = uniqueEmail('editor');
  const editorToken = await registerAndGetToken(editorEmail, 'Editor');
  const viewerEmail = uniqueEmail('viewer');
  const viewerToken = await registerAndGetToken(viewerEmail, 'Viewer');
  const outsiderToken = await registerAndGetToken(uniqueEmail('outsider'), 'Outsider');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'RBAC Test Board' });

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

  const auditAfterMemberAdds = await pool.query(
    `SELECT event_type
     FROM audit_logs
     WHERE board_id = $1::uuid
     ORDER BY id ASC`,
    [boardId]
  );
  assert.ok(auditAfterMemberAdds.rows.some((row) => row.event_type === 'board.created'));
  assert.ok(
    auditAfterMemberAdds.rows.filter((row) => row.event_type === 'board.member_added').length >= 2
  );

  const ownerBoardAuditRes = await request(app)
    .get(`/api/boards/${boardId}/audit`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerBoardAuditRes.statusCode, 200);
  assert.ok(ownerBoardAuditRes.body.items.length >= 3);

  const outsiderAuditRes = await request(app)
    .get(`/api/boards/${boardId}/audit`)
    .set('Authorization', `Bearer ${outsiderToken}`);
  assert.equal(outsiderAuditRes.statusCode, 403);

  const ownerMeRes = await request(app)
    .get(`/api/boards/${boardId}/me`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerMeRes.statusCode, 200);
  assert.equal(ownerMeRes.body.role, 'owner');

  const editorMeRes = await request(app)
    .get(`/api/boards/${boardId}/me`)
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(editorMeRes.statusCode, 200);
  assert.equal(editorMeRes.body.role, 'editor');

  const viewerMeRes = await request(app)
    .get(`/api/boards/${boardId}/me`)
    .set('Authorization', `Bearer ${viewerToken}`);
  assert.equal(viewerMeRes.statusCode, 200);
  assert.equal(viewerMeRes.body.role, 'viewer');

  const outsiderMeRes = await request(app)
    .get(`/api/boards/${boardId}/me`)
    .set('Authorization', `Bearer ${outsiderToken}`);
  assert.equal(outsiderMeRes.statusCode, 403);

  const viewerCreateList = await request(app)
    .post('/api/lists')
    .set('Authorization', `Bearer ${viewerToken}`)
    .send({ boardId, title: 'Viewer cannot create', orderIndex: 0 });
  assert.equal(viewerCreateList.statusCode, 403);

  const editorCreateList = await request(app)
    .post('/api/lists')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({ boardId, title: 'Editor can create', orderIndex: 0 });
  assert.equal(editorCreateList.statusCode, 201);

  const listId = editorCreateList.body.id;

  const viewerCreateCard = await request(app)
    .post('/api/cards')
    .set('Authorization', `Bearer ${viewerToken}`)
    .send({ boardId, listId, title: 'Nope', description: '', orderIndex: 0 });
  assert.equal(viewerCreateCard.statusCode, 403);

  const editorCreateCard = await request(app)
    .post('/api/cards')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({ boardId, listId, title: 'Allowed', description: 'Editor write', orderIndex: 0 });
  assert.equal(editorCreateCard.statusCode, 201);

  const editorAddMember = await request(app)
    .post(`/api/boards/${boardId}/members`)
    .set('Authorization', `Bearer ${editorToken}`)
    .send({ email: uniqueEmail('another'), role: 'viewer' });
  assert.equal(editorAddMember.statusCode, 403);

  const ownerInfo = ownerMeRes.body;

  const demoteLastOwner = await request(app)
    .patch(`/api/boards/${boardId}/members/${ownerInfo.userId}`)
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ role: 'editor' });
  assert.equal(demoteLastOwner.statusCode, 400);

  const removeLastOwner = await request(app)
    .delete(`/api/boards/${boardId}/members/${ownerInfo.userId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(removeLastOwner.statusCode, 400);
});

test('Sync endpoints: push/pull are versioned, idempotent, and role-aware', async () => {
  await clearDb();

  const ownerToken = await registerAndGetToken(uniqueEmail('owner-sync'), 'Owner Sync');
  const editorEmail = uniqueEmail('editor-sync');
  const editorToken = await registerAndGetToken(editorEmail, 'Editor Sync');
  const viewerEmail = uniqueEmail('viewer-sync');
  const viewerToken = await registerAndGetToken(viewerEmail, 'Viewer Sync');

  const boardRes = await request(app)
    .post('/api/boards')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ name: 'Sync Test Board' });
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

  const viewerPushRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${viewerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'viewer-op-1',
          boardId,
          operationType: 'card.created',
          entityType: 'card',
          entityId: '33333333-3333-4333-8333-333333333333',
          payload: {
            listId: '11111111-1111-4111-8111-111111111111',
            title: 'Should fail'
          }
        }
      ]
    });
  assert.equal(viewerPushRes.statusCode, 403);

  const malformedSyncRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'malformed-op-1',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: 'not-a-uuid',
          payload: { title: 'Bad payload' }
        }
      ]
    });
  assert.equal(malformedSyncRes.statusCode, 400);
  assert.equal(malformedSyncRes.body.error, 'entityId must be a valid UUID');

  const boardCreateViaSyncRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'owner-board-create-op',
          boardId,
          operationType: 'board.created',
          entityType: 'board',
          entityId: boardId,
          payload: { name: 'Should be rejected' }
        }
      ]
    });
  assert.equal(boardCreateViaSyncRes.statusCode, 400);
  assert.equal(
    boardCreateViaSyncRes.body.error,
    'board.created is not supported via sync/push; create boards with POST /api/boards'
  );

  const editorPushListCreateRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-list-op-1',
          boardId,
          operationType: 'list.created',
          entityType: 'list',
          entityId: '11111111-1111-4111-8111-111111111111',
          payload: { title: 'From sync list', orderIndex: 0 }
        }
      ]
    });
  assert.equal(editorPushListCreateRes.statusCode, 201);
  const listId = editorPushListCreateRes.body.items[0].entityId;

  const ownerListsRes = await request(app)
    .get(`/api/lists/board/${boardId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerListsRes.statusCode, 200);
  const syncedList = ownerListsRes.body.items.find((item) => item.id === listId);
  assert.ok(syncedList);
  assert.equal(syncedList.title, 'From sync list');
  assert.equal(syncedList.version, 1);

  const editorPushRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-1',
          boardId,
          operationType: 'card.created',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: { listId, title: 'Created offline', description: 'sync create', orderIndex: 1 }
        }
      ]
    });

  assert.equal(editorPushRes.statusCode, 201);
  assert.equal(editorPushRes.body.items.length, 1);
  assert.equal(editorPushRes.body.items[0].status, 'applied');
  assert.ok(Number.isInteger(editorPushRes.body.items[0].version));
  const firstVersion = editorPushRes.body.items[0].version;

  const duplicatePushRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-1',
          boardId,
          operationType: 'card.created',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: { listId, title: 'Created offline', description: 'sync create', orderIndex: 1 }
        }
      ]
    });
  assert.equal(duplicatePushRes.statusCode, 201);
  assert.equal(duplicatePushRes.body.items[0].status, 'duplicate');
  assert.equal(duplicatePushRes.body.items[0].version, firstVersion);

  const ownerCardsAfterCreateRes = await request(app)
    .get(`/api/cards/list/${listId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerCardsAfterCreateRes.statusCode, 200);
  const createdCard = ownerCardsAfterCreateRes.body.items.find(
    (item) => item.id === '22222222-2222-4222-8222-222222222222'
  );
  assert.ok(createdCard);
  assert.equal(createdCard.version, 1);

  const editorPushUpdateRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-2',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: {
            title: 'Updated by sync',
            description: 'sync update',
            orderIndex: 2,
            expectedVersion: createdCard.version
          }
        }
      ]
    });
  assert.equal(editorPushUpdateRes.statusCode, 201);

  const ownerCardsAfterUpdateRes = await request(app)
    .get(`/api/cards/list/${listId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerCardsAfterUpdateRes.statusCode, 200);
  assert.ok(
    ownerCardsAfterUpdateRes.body.items.some(
      (item) =>
        item.id === '22222222-2222-4222-8222-222222222222' &&
        item.title === 'Updated by sync' &&
        item.description === 'sync update' &&
        item.version === 2
    )
  );

  const staleUpdateConflictRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-2-stale',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: {
            title: 'Should conflict',
            expectedVersion: 1
          }
        }
      ]
    });
  const metricsBeforeConflictRes = await request(app).get('/metrics');
  const conflictsBefore = metricsBeforeConflictRes.body.counters.syncPushConflictsTotal;

  const staleUpdateConflictRes2 = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-2-stale-metrics',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: {
            title: 'Should conflict for metric',
            expectedVersion: 1
          }
        }
      ]
    });
  assert.equal(staleUpdateConflictRes2.statusCode, 409);

  const failuresAfterConflictRes = await request(app)
    .get('/api/sync/failures')
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(failuresAfterConflictRes.statusCode, 200);
  const pendingFailure = failuresAfterConflictRes.body.items.find(
    (item) => item.clientOperationId === 'editor-op-2-stale-metrics'
  );
  assert.ok(pendingFailure);
  assert.ok(pendingFailure.attemptCount >= 1);
  assert.equal(pendingFailure.statusCode, 409);

  const missingListId = '88888888-8888-4888-8888-888888888888';
  const retryEndpointCardId = '77777777-7777-4777-8777-777777777777';
  const failedCreateForRetryEndpointRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-retry-endpoint-card-create',
          boardId,
          operationType: 'card.created',
          entityType: 'card',
          entityId: retryEndpointCardId,
          payload: {
            listId: missingListId,
            title: 'Retry endpoint card',
            description: 'will succeed after list exists',
            orderIndex: 0
          }
        }
      ]
    });
  assert.equal(failedCreateForRetryEndpointRes.statusCode, 404);

  const failuresBeforeRetryEndpointRes = await request(app)
    .get('/api/sync/failures')
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(failuresBeforeRetryEndpointRes.statusCode, 200);
  const retryEndpointFailure = failuresBeforeRetryEndpointRes.body.items.find(
    (item) => item.clientOperationId === 'editor-op-retry-endpoint-card-create'
  );
  assert.ok(retryEndpointFailure);
  const attemptsBeforeRetryEndpoint = retryEndpointFailure.attemptCount;

  const retryEndpointStillFailsRes = await request(app)
    .post(`/api/sync/failures/${retryEndpointFailure.id}/retry`)
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(retryEndpointStillFailsRes.statusCode, 404);

  const failuresAfterRetryFailRes = await request(app)
    .get('/api/sync/failures')
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(failuresAfterRetryFailRes.statusCode, 200);
  const retryEndpointFailureAfterFailedRetry = failuresAfterRetryFailRes.body.items.find(
    (item) => item.clientOperationId === 'editor-op-retry-endpoint-card-create'
  );
  assert.ok(retryEndpointFailureAfterFailedRetry);
  assert.ok(retryEndpointFailureAfterFailedRetry.attemptCount >= attemptsBeforeRetryEndpoint + 1);

  const createListForRetryRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-retry-endpoint-list-create',
          boardId,
          operationType: 'list.created',
          entityType: 'list',
          entityId: missingListId,
          payload: {
            title: 'Retry Endpoint List',
            orderIndex: 99
          }
        }
      ]
    });
  assert.equal(createListForRetryRes.statusCode, 201);

  const retryEndpointSuccessRes = await request(app)
    .post(`/api/sync/failures/${retryEndpointFailure.id}/retry`)
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(retryEndpointSuccessRes.statusCode, 201);
  assert.equal(retryEndpointSuccessRes.body.item.status, 'applied');
  assert.equal(
    retryEndpointSuccessRes.body.item.clientOperationId,
    'editor-op-retry-endpoint-card-create'
  );
  assert.equal(retryEndpointSuccessRes.body.item.entityId, retryEndpointCardId);

  const cardsAfterRetryEndpointSuccessRes = await request(app)
    .get(`/api/cards/list/${missingListId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(cardsAfterRetryEndpointSuccessRes.statusCode, 200);
  assert.ok(
    cardsAfterRetryEndpointSuccessRes.body.items.some((item) => item.id === retryEndpointCardId)
  );

  const failuresAfterRetryEndpointSuccessRes = await request(app)
    .get('/api/sync/failures')
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(failuresAfterRetryEndpointSuccessRes.statusCode, 200);
  assert.ok(
    failuresAfterRetryEndpointSuccessRes.body.items.every(
      (item) => item.clientOperationId !== 'editor-op-retry-endpoint-card-create'
    )
  );

  const retryResolvedRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-2-stale-metrics',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: {
            title: 'Retry success',
            expectedVersion: 2
          }
        }
      ]
    });
  assert.equal(retryResolvedRes.statusCode, 201);

  const failuresAfterRetryRes = await request(app)
    .get('/api/sync/failures')
    .set('Authorization', `Bearer ${editorToken}`);
  assert.equal(failuresAfterRetryRes.statusCode, 200);
  assert.ok(
    failuresAfterRetryRes.body.items.every(
      (item) => item.clientOperationId !== 'editor-op-2-stale-metrics'
    )
  );

  const metricsAfterConflictRes = await request(app).get('/metrics');
  const conflictsAfter = metricsAfterConflictRes.body.counters.syncPushConflictsTotal;
  assert.ok(conflictsAfter >= conflictsBefore + 1);

  assert.equal(staleUpdateConflictRes.statusCode, 409);
  assert.equal(staleUpdateConflictRes.body.error, 'card version conflict');
  assert.equal(staleUpdateConflictRes.body.conflict.serverSnapshot.entityType, 'card');
  assert.equal(staleUpdateConflictRes.body.conflict.serverSnapshot.entity.version, 2);

  const atomicRollbackRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-atomic-1',
          boardId,
          operationType: 'card.created',
          entityType: 'card',
          entityId: '66666666-6666-4666-8666-666666666666',
          payload: {
            listId,
            title: 'Should rollback',
            description: 'batch atomicity',
            orderIndex: 9
          }
        },
        {
          clientOperationId: 'editor-op-atomic-2',
          boardId,
          operationType: 'card.updated',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: {
            title: 'Force conflict',
            expectedVersion: 1
          }
        }
      ]
    });
  assert.equal(atomicRollbackRes.statusCode, 409);

  const cardsAfterAtomicFailureRes = await request(app)
    .get(`/api/cards/list/${listId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(cardsAfterAtomicFailureRes.statusCode, 200);
  assert.ok(
    cardsAfterAtomicFailureRes.body.items.every(
      (item) => item.id !== '66666666-6666-4666-8666-666666666666'
    )
  );

  const editorPushDeleteRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${editorToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'editor-op-3',
          boardId,
          operationType: 'card.deleted',
          entityType: 'card',
          entityId: '22222222-2222-4222-8222-222222222222',
          payload: { expectedVersion: 3 }
        }
      ]
    });
  assert.equal(editorPushDeleteRes.statusCode, 201);

  const ownerCardsAfterDeleteRes = await request(app)
    .get(`/api/cards/list/${listId}`)
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerCardsAfterDeleteRes.statusCode, 200);
  assert.ok(
    ownerCardsAfterDeleteRes.body.items.every(
      (item) => item.id !== '22222222-2222-4222-8222-222222222222'
    )
  );

  const ownerPullAllRes = await request(app)
    .get('/api/sync/pull')
    .query({ sinceVersion: 0 })
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerPullAllRes.statusCode, 200);
  assert.ok(ownerPullAllRes.body.latestVersion >= firstVersion);
  assert.ok(ownerPullAllRes.body.items.some((item) => item.version === firstVersion));

  const viewerPullBoardRes = await request(app)
    .get('/api/sync/pull')
    .query({ sinceVersion: 0, boardId })
    .set('Authorization', `Bearer ${viewerToken}`);
  assert.equal(viewerPullBoardRes.statusCode, 200);
  assert.ok(viewerPullBoardRes.body.items.some((item) => item.version === firstVersion));

  const ownerPullSinceRes = await request(app)
    .get('/api/sync/pull')
    .query({ sinceVersion: firstVersion, boardId })
    .set('Authorization', `Bearer ${ownerToken}`);
  assert.equal(ownerPullSinceRes.statusCode, 200);
  assert.ok(ownerPullSinceRes.body.items.length >= 1);
  assert.ok(ownerPullSinceRes.body.items.every((item) => item.version > firstVersion));
  assert.ok(ownerPullSinceRes.body.latestVersion >= firstVersion);

  const boardDeleteRes = await request(app)
    .post('/api/sync/push')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({
      operations: [
        {
          clientOperationId: 'owner-op-board-delete-audit',
          boardId,
          operationType: 'board.deleted',
          entityType: 'board',
          entityId: boardId,
          payload: { expectedVersion: 1 }
        }
      ]
    });
  assert.equal(boardDeleteRes.statusCode, 201);

  const boardDeleteAudit = await pool.query(
    `SELECT event_type
     FROM audit_logs
     WHERE board_id = $1::uuid
       AND event_type = 'board.deleted'`,
    [boardId]
  );
  assert.equal(boardDeleteAudit.rowCount, 1);
});

test('WebSocket channels: JWT auth, board subscription authorization, and sync broadcast', async () => {
  await clearDb();

  const { server, baseUrl, wsUrl } = await startHttpAndWsServer();
  const api = request(baseUrl);

  try {
    const password = 'Password123';
    const ownerEmail = uniqueEmail('ws-owner');
    const viewerEmail = uniqueEmail('ws-viewer');
    const outsiderEmail = uniqueEmail('ws-outsider');

    const ownerRegister = await api
      .post('/api/auth/register')
      .send({ email: ownerEmail, password, displayName: 'WS Owner' });
    assert.equal(ownerRegister.statusCode, 201);
    const ownerToken = ownerRegister.body.token;

    const viewerRegister = await api
      .post('/api/auth/register')
      .send({ email: viewerEmail, password, displayName: 'WS Viewer' });
    assert.equal(viewerRegister.statusCode, 201);
    const viewerToken = viewerRegister.body.token;

    const outsiderRegister = await api
      .post('/api/auth/register')
      .send({ email: outsiderEmail, password, displayName: 'WS Outsider' });
    assert.equal(outsiderRegister.statusCode, 201);
    const outsiderToken = outsiderRegister.body.token;

    const boardRes = await api
      .post('/api/boards')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: 'WS Integration Board' });
    assert.equal(boardRes.statusCode, 201);
    const boardId = boardRes.body.id;

    const addViewerRes = await api
      .post(`/api/boards/${boardId}/members`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ email: viewerEmail, role: 'viewer' });
    assert.equal(addViewerRes.statusCode, 201);

    const listRes = await api
      .post('/api/lists')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ boardId, title: 'WS List', orderIndex: 0 });
    assert.equal(listRes.statusCode, 201);
    const listId = listRes.body.id;

    const viewerWs = new WebSocket(`${wsUrl}/?token=${encodeURIComponent(viewerToken)}`);
    const viewerWelcome = await waitForWsMessage(viewerWs, (msg) => msg.type === 'welcome');
    assert.equal(viewerWelcome.reconnectHint, 'resubscribe_and_catchup');

    viewerWs.send(JSON.stringify({ type: 'subscribe_board', boardId }));
    const viewerSubscribed = await waitForWsMessage(
      viewerWs,
      (msg) => msg.type === 'subscribed_board' && msg.boardId === boardId
    );
    assert.equal(viewerSubscribed.role, 'viewer');

    const outsiderWs = new WebSocket(`${wsUrl}/?token=${encodeURIComponent(outsiderToken)}`);
    await waitForWsMessage(outsiderWs, (msg) => msg.type === 'welcome');
    outsiderWs.send(JSON.stringify({ type: 'subscribe_board', boardId }));
    const outsiderError = await waitForWsMessage(
      outsiderWs,
      (msg) => msg.type === 'error' && msg.error === 'forbidden_board_subscription'
    );
    assert.equal(outsiderError.boardId, boardId);

    const expectedEntityId = '55555555-5555-4555-8555-555555555555';
    const viewerBroadcastPromise = waitForWsMessage(
      viewerWs,
      (msg) =>
        msg.type === 'sync.operation.applied' &&
        msg.data?.boardId === boardId &&
        msg.data?.entityId === expectedEntityId
    );

    const pushRes = await api
      .post('/api/sync/push')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        operations: [
          {
            clientOperationId: 'ws-broadcast-op-1',
            boardId,
            operationType: 'card.created',
            entityType: 'card',
            entityId: expectedEntityId,
            payload: {
              listId,
              title: 'Broadcasted Card',
              description: 'ws integration',
              orderIndex: 0
            }
          }
        ]
      });
    assert.equal(pushRes.statusCode, 201);

    const viewerBroadcast = await viewerBroadcastPromise;
    assert.equal(viewerBroadcast.data.operationType, 'card.created');
    assert.equal(viewerBroadcast.data.entityType, 'card');
    assert.ok(Number.isInteger(viewerBroadcast.data.version));

    viewerWs.send(
      JSON.stringify({
        type: 'sync_catchup',
        boardId,
        sinceVersion: viewerBroadcast.data.version - 1,
        limit: 50
      })
    );

    const catchupResponse = await waitForWsMessage(
      viewerWs,
      (msg) =>
        msg.type === 'sync.catchup' &&
        msg.boardId === boardId &&
        Array.isArray(msg.items)
    );
    assert.ok(catchupResponse.latestVersion >= viewerBroadcast.data.version);
    assert.ok(catchupResponse.items.some((item) => item.version === viewerBroadcast.data.version));

    viewerWs.close();
    outsiderWs.close();
  } finally {
    app.locals.broadcastSyncOperation = () => {};
    await stopServer(server);
  }
});

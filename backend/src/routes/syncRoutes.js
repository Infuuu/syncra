const express = require('express');

const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const syncRepository = require('../repositories/syncRepository');
const syncFailureRepository = require('../repositories/syncFailureRepository');
const auditLogRepository = require('../repositories/auditLogRepository');
const { hasRequiredRole } = require('../services/authorizationService');
const { validateSyncPushOperation } = require('../services/syncValidationService');
const metricsService = require('../services/metricsService');
const {
  SyncApplyError,
  SyncApplyConflictError,
  applySyncOperationToCanonicalTables
} = require('../services/syncApplyService');
const {
  parseSyncPushBody,
  parseSyncFailuresQuery,
  parseSyncRetryParams,
  parseSyncPullQuery
} = require('../validation/requestValidation');
const { badRequest, forbidden, notFound, serverError } = require('../utils/http');

const router = express.Router();

const mapSyncInsertResult = (inserted) => ({
  status: inserted.status,
  clientOperationId: inserted.operation.clientOperationId,
  version: inserted.operation.version,
  boardId: inserted.operation.boardId,
  operationType: inserted.operation.operationType,
  entityType: inserted.operation.entityType,
  entityId: inserted.operation.entityId,
  createdAt: inserted.operation.createdAt
});

const normalizeOperationAction = (operationType) => {
  const value = String(operationType || '').trim().toLowerCase();
  const action = value.includes('.') ? value.split('.').pop() : value;
  if (action === 'create') return 'created';
  if (action === 'update') return 'updated';
  if (action === 'delete') return 'deleted';
  if (action === 'move') return 'moved';
  return action;
};

router.post('/push', async (req, res) => {
  const parsed = parseSyncPushBody(req.body);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { operations } = parsed.value;

  try {
    const roleCache = new Map();
    const normalizedOperations = [];
    const broadcastSyncOperation =
      typeof req.app?.locals?.broadcastSyncOperation === 'function'
        ? req.app.locals.broadcastSyncOperation
        : null;

    for (const raw of operations) {
      validateSyncPushOperation(raw);

      const board = await boardRepository.getBoardById(raw.boardId);
      if (!board) return notFound(res, `board not found: ${raw.boardId}`);

      const cacheKey = raw.boardId;
      let role = roleCache.get(cacheKey);
      if (!role) {
        role = await boardMemberRepository.getBoardRole({
          boardId: raw.boardId,
          userId: req.auth.userId
        });
        roleCache.set(cacheKey, role || '');
      }

      if (!hasRequiredRole(role, 'editor')) {
        return forbidden(res, `editor or owner role is required for board: ${raw.boardId}`);
      }
      normalizedOperations.push({
        boardId: raw.boardId,
        actorUserId: req.auth.userId,
        clientOperationId: raw.clientOperationId,
        operationType: raw.operationType,
        entityType: raw.entityType,
        entityId: raw.entityId,
        payload: raw.payload
      });
    }

    const insertedResults = await syncRepository.applySyncOperationsBatch({
      operations: normalizedOperations,
      applyCanonicalMutation: async (client, mappedOperation) => {
        await applySyncOperationToCanonicalTables(client, mappedOperation);
        const action = normalizeOperationAction(mappedOperation.operationType);
        if (mappedOperation.entityType === 'board' && action === 'deleted') {
          await auditLogRepository.createAuditLog({
            client,
            actorUserId: mappedOperation.actorUserId,
            boardId: mappedOperation.boardId,
            eventType: 'board.deleted',
            entityType: 'board',
            entityId: mappedOperation.entityId,
            metadata: {
              via: 'sync.push',
              operationVersion: mappedOperation.version
            }
          });
        }
      }
    });

    const results = [];
    for (const inserted of insertedResults) {
      results.push(mapSyncInsertResult(inserted));

      if (inserted.status === 'applied' && broadcastSyncOperation) {
        try {
          broadcastSyncOperation({
            version: inserted.operation.version,
            boardId: inserted.operation.boardId,
            actorUserId: inserted.operation.actorUserId,
            clientOperationId: inserted.operation.clientOperationId,
            operationType: inserted.operation.operationType,
            entityType: inserted.operation.entityType,
            entityId: inserted.operation.entityId,
            payload: inserted.operation.payload,
            createdAt: inserted.operation.createdAt
          });
        } catch (_error) {
          // ignore websocket broadcast errors; HTTP mutation already committed
        }
      }

      if (inserted.operation.clientOperationId) {
        await syncFailureRepository.resolveSyncFailureByClientOperation({
          actorUserId: req.auth.userId,
          clientOperationId: inserted.operation.clientOperationId
        });
      }
    }

    const latestVersion = results.length > 0 ? results[results.length - 1].version : 0;

    return res.status(201).json({
      items: results,
      latestVersion
    });
  } catch (error) {
    const failedOperation = error.failedOperation || null;

    const recordFailureIfPossible = async (statusCode, message) => {
      if (!failedOperation) return;
      await syncFailureRepository.recordSyncFailure({
        actorUserId: req.auth.userId,
        boardId: failedOperation.boardId || null,
        clientOperationId: failedOperation.clientOperationId || null,
        operationType: failedOperation.operationType || 'unknown',
        entityType: failedOperation.entityType || 'unknown',
        entityId: failedOperation.entityId || 'unknown',
        payload: failedOperation.payload || {},
        statusCode,
        errorCode: error.name || null,
        errorMessage: message
      });
    };

    if (error instanceof SyncApplyConflictError) {
      await recordFailureIfPossible(409, error.message);
      metricsService.incrementCounter('syncPushConflictsTotal', 1);
      metricsService.incrementLabeledCounter(
        'syncPushErrorsTotal',
        { reason: 'conflict', status_code: '409' },
        1
      );
      return res.status(409).json({
        error: error.message,
        conflict: {
          serverSnapshot: error.snapshot
        }
      });
    }
    if (error instanceof SyncApplyError) {
      await recordFailureIfPossible(error.statusCode || 400, error.message);
      metricsService.incrementLabeledCounter(
        'syncPushErrorsTotal',
        { reason: 'apply_error', status_code: String(error.statusCode || 400) },
        1
      );
      if (error.statusCode === 404) return notFound(res, error.message);
      if (error.statusCode === 403) return forbidden(res, error.message);
      return badRequest(res, error.message);
    }
    await recordFailureIfPossible(500, error.message || 'internal_server_error');
    metricsService.incrementLabeledCounter(
      'syncPushErrorsTotal',
      { reason: 'internal_error', status_code: '500' },
      1
    );
    return serverError(res, error.message);
  }
});

router.get('/failures', async (req, res) => {
  const parsed = parseSyncFailuresQuery(req.query);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { boardId, limit } = parsed.value;

  try {
    if (boardId) {
      const board = await boardRepository.getBoardById(boardId);
      if (!board) return notFound(res, 'board not found');

      const role = await boardMemberRepository.getBoardRole({
        boardId,
        userId: req.auth.userId
      });
      if (!role) return forbidden(res, 'you do not have access to this board');
    }

    const items = await syncFailureRepository.listOpenFailuresByActor({
      actorUserId: req.auth.userId,
      boardId,
      limit
    });

    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/failures/:failureId/retry', async (req, res) => {
  const parsed = parseSyncRetryParams(req.params);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { failureId } = parsed.value;

  try {
    const failure = await syncFailureRepository.getOpenFailureByIdForActor({
      actorUserId: req.auth.userId,
      failureId
    });
    if (!failure) return notFound(res, 'sync failure not found');

    if (failure.boardId) {
      const board = await boardRepository.getBoardById(failure.boardId);
      if (!board) return notFound(res, 'board not found');

      const role = await boardMemberRepository.getBoardRole({
        boardId: failure.boardId,
        userId: req.auth.userId
      });
      if (!hasRequiredRole(role, 'editor')) {
        return forbidden(res, `editor or owner role is required for board: ${failure.boardId}`);
      }
    }

    const [inserted] = await syncRepository.applySyncOperationsBatch({
      operations: [
        {
          boardId: failure.boardId,
          actorUserId: req.auth.userId,
          clientOperationId: failure.clientOperationId,
          operationType: failure.operationType,
          entityType: failure.entityType,
          entityId: failure.entityId,
          payload: failure.payload || {}
        }
      ],
      applyCanonicalMutation: async (client, mappedOperation) => {
        await applySyncOperationToCanonicalTables(client, mappedOperation);
        const action = normalizeOperationAction(mappedOperation.operationType);
        if (mappedOperation.entityType === 'board' && action === 'deleted') {
          await auditLogRepository.createAuditLog({
            client,
            actorUserId: mappedOperation.actorUserId,
            boardId: mappedOperation.boardId,
            eventType: 'board.deleted',
            entityType: 'board',
            entityId: mappedOperation.entityId,
            metadata: {
              via: 'sync.retry',
              operationVersion: mappedOperation.version
            }
          });
        }
      }
    });

    const result = mapSyncInsertResult(inserted);

    const broadcastSyncOperation =
      typeof req.app?.locals?.broadcastSyncOperation === 'function'
        ? req.app.locals.broadcastSyncOperation
        : null;
    if (inserted.status === 'applied' && broadcastSyncOperation) {
      try {
        broadcastSyncOperation({
          version: inserted.operation.version,
          boardId: inserted.operation.boardId,
          actorUserId: inserted.operation.actorUserId,
          clientOperationId: inserted.operation.clientOperationId,
          operationType: inserted.operation.operationType,
          entityType: inserted.operation.entityType,
          entityId: inserted.operation.entityId,
          payload: inserted.operation.payload,
          createdAt: inserted.operation.createdAt
        });
      } catch (_error) {
        // ignore websocket broadcast errors; HTTP mutation already committed
      }
    }

    await syncFailureRepository.resolveSyncFailureById({
      actorUserId: req.auth.userId,
      failureId
    });
    if (inserted.operation.clientOperationId) {
      await syncFailureRepository.resolveSyncFailureByClientOperation({
        actorUserId: req.auth.userId,
        clientOperationId: inserted.operation.clientOperationId
      });
    }

    return res.status(201).json({
      item: result,
      latestVersion: result.version
    });
  } catch (error) {
    if (error instanceof SyncApplyConflictError) {
      await syncFailureRepository.markRetryFailureAttempt({
        actorUserId: req.auth.userId,
        failureId,
        statusCode: 409,
        errorCode: error.name,
        errorMessage: error.message
      });
      metricsService.incrementCounter('syncPushConflictsTotal', 1);
      metricsService.incrementLabeledCounter(
        'syncPushErrorsTotal',
        { reason: 'conflict', status_code: '409' },
        1
      );
      return res.status(409).json({
        error: error.message,
        conflict: {
          serverSnapshot: error.snapshot
        }
      });
    }

    if (error instanceof SyncApplyError) {
      await syncFailureRepository.markRetryFailureAttempt({
        actorUserId: req.auth.userId,
        failureId,
        statusCode: error.statusCode || 400,
        errorCode: error.name,
        errorMessage: error.message
      });
      metricsService.incrementLabeledCounter(
        'syncPushErrorsTotal',
        { reason: 'apply_error', status_code: String(error.statusCode || 400) },
        1
      );
      if (error.statusCode === 404) return notFound(res, error.message);
      if (error.statusCode === 403) return forbidden(res, error.message);
      return badRequest(res, error.message);
    }

    await syncFailureRepository.markRetryFailureAttempt({
      actorUserId: req.auth.userId,
      failureId,
      statusCode: 500,
      errorCode: error.name || null,
      errorMessage: error.message || 'internal_server_error'
    });
    metricsService.incrementLabeledCounter(
      'syncPushErrorsTotal',
      { reason: 'internal_error', status_code: '500' },
      1
    );
    return serverError(res, error.message);
  }
});

router.get('/pull', async (req, res) => {
  const parsed = parseSyncPullQuery(req.query);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { sinceVersion, boardId, limit } = parsed.value;

  try {
    if (boardId) {
      const board = await boardRepository.getBoardById(boardId);
      if (!board) return notFound(res, 'board not found');

      const role = await boardMemberRepository.getBoardRole({
        boardId,
        userId: req.auth.userId
      });
      if (!role) return forbidden(res, 'you do not have access to this board');
    }

    const items = await syncRepository.listOperationsForUserSinceVersion({
      userId: req.auth.userId,
      sinceVersion,
      boardId,
      limit
    });

    const latestVersion = await syncRepository.getLatestVisibleVersionForUser({
      userId: req.auth.userId,
      sinceVersion,
      boardId
    });

    return res.json({
      items,
      latestVersion
    });
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

const express = require('express');

const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const syncRepository = require('../repositories/syncRepository');
const { hasRequiredRole } = require('../services/authorizationService');
const { validateSyncPushOperation } = require('../services/syncValidationService');
const {
  SyncApplyError,
  SyncApplyConflictError,
  applySyncOperationToCanonicalTables
} = require('../services/syncApplyService');
const { badRequest, forbidden, notFound, serverError } = require('../utils/http');

const router = express.Router();

const normalizePushOperation = (input) => {
  const boardId = String(input?.boardId || '').trim();
  const clientOperationIdRaw = input?.clientOperationId;
  const clientOperationId =
    typeof clientOperationIdRaw === 'string' && clientOperationIdRaw.trim()
      ? clientOperationIdRaw.trim()
      : null;
  const operationType = String(input?.operationType || '').trim();
  const entityType = String(input?.entityType || '').trim();
  const entityId = String(input?.entityId || '').trim();
  const payload = input?.payload && typeof input.payload === 'object' ? input.payload : {};

  if (!boardId) return { error: 'boardId is required' };
  if (!operationType) return { error: 'operationType is required' };
  if (!entityType) return { error: 'entityType is required' };
  if (!entityId) return { error: 'entityId is required' };

  return {
    boardId,
    clientOperationId,
    operationType,
    entityType,
    entityId,
    payload
  };
};

router.post('/push', async (req, res) => {
  const operations = Array.isArray(req.body?.operations) ? req.body.operations : null;
  if (!operations) return badRequest(res, 'operations array is required');
  if (operations.length === 0) return badRequest(res, 'operations must not be empty');
  if (operations.length > 100) return badRequest(res, 'operations limit is 100 per request');

  try {
    const roleCache = new Map();
    const normalizedOperations = [];
    const broadcastSyncOperation =
      typeof req.app?.locals?.broadcastSyncOperation === 'function'
        ? req.app.locals.broadcastSyncOperation
        : null;

    for (const raw of operations) {
      const operation = normalizePushOperation(raw);
      if (operation.error) return badRequest(res, operation.error);
      validateSyncPushOperation(operation);

      const board = await boardRepository.getBoardById(operation.boardId);
      if (!board) return notFound(res, `board not found: ${operation.boardId}`);

      const cacheKey = operation.boardId;
      let role = roleCache.get(cacheKey);
      if (!role) {
        role = await boardMemberRepository.getBoardRole({
          boardId: operation.boardId,
          userId: req.auth.userId
        });
        roleCache.set(cacheKey, role || '');
      }

      if (!hasRequiredRole(role, 'editor')) {
        return forbidden(res, `editor or owner role is required for board: ${operation.boardId}`);
      }
      normalizedOperations.push({
        boardId: operation.boardId,
        actorUserId: req.auth.userId,
        clientOperationId: operation.clientOperationId,
        operationType: operation.operationType,
        entityType: operation.entityType,
        entityId: operation.entityId,
        payload: operation.payload
      });
    }

    const insertedResults = await syncRepository.applySyncOperationsBatch({
      operations: normalizedOperations,
      applyCanonicalMutation: async (client, mappedOperation) => {
        await applySyncOperationToCanonicalTables(client, mappedOperation);
      }
    });

    const results = [];
    for (const inserted of insertedResults) {
      results.push({
        status: inserted.status,
        clientOperationId: inserted.operation.clientOperationId,
        version: inserted.operation.version,
        boardId: inserted.operation.boardId,
        operationType: inserted.operation.operationType,
        entityType: inserted.operation.entityType,
        entityId: inserted.operation.entityId,
        createdAt: inserted.operation.createdAt
      });

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
    }

    const latestVersion = results.length > 0 ? results[results.length - 1].version : 0;

    return res.status(201).json({
      items: results,
      latestVersion
    });
  } catch (error) {
    if (error instanceof SyncApplyConflictError) {
      return res.status(409).json({
        error: error.message,
        conflict: {
          serverSnapshot: error.snapshot
        }
      });
    }
    if (error instanceof SyncApplyError) {
      if (error.statusCode === 404) return notFound(res, error.message);
      if (error.statusCode === 403) return forbidden(res, error.message);
      return badRequest(res, error.message);
    }
    return serverError(res, error.message);
  }
});

router.get('/pull', async (req, res) => {
  const sinceVersionRaw = req.query?.sinceVersion;
  const sinceVersion = Number(sinceVersionRaw ?? 0);
  const boardId = req.query?.boardId ? String(req.query.boardId).trim() : null;
  const limitRaw = Number(req.query?.limit ?? 500);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 1000) : 500;

  if (!Number.isInteger(sinceVersion) || sinceVersion < 0) {
    return badRequest(res, 'sinceVersion must be a non-negative integer');
  }

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

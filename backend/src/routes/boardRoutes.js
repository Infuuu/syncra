const express = require('express');
const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const auditLogRepository = require('../repositories/auditLogRepository');
const { badRequest, notFound, forbidden, serverError } = require('../utils/http');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const items = await boardRepository.listBoardsForUser(req.auth.userId);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/', async (req, res) => {
  const name = String(req.body?.name || '').trim();
  if (!name) return badRequest(res, 'name is required');

  try {
    const board = await boardRepository.createBoardForUser({ name, userId: req.auth.userId });
    await auditLogRepository.createAuditLog({
      actorUserId: req.auth.userId,
      boardId: board.id,
      eventType: 'board.created',
      entityType: 'board',
      entityId: board.id,
      metadata: {
        name: board.name
      }
    });
    return res.status(201).json(board);
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.get('/:boardId/me', async (req, res) => {
  const boardId = req.params.boardId;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const role = await boardMemberRepository.getBoardRole({
      boardId,
      userId: req.auth.userId
    });
    if (!role) return forbidden(res, 'you do not have access to this board');

    return res.json({
      boardId,
      userId: req.auth.userId,
      role
    });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.get('/:boardId', async (req, res) => {
  try {
    const board = await boardRepository.getBoardById(req.params.boardId);
    if (!board) return notFound(res, 'board not found');
    const role = await boardMemberRepository.getBoardRole({
      boardId: board.id,
      userId: req.auth.userId
    });
    if (!role) return forbidden(res, 'you do not have access to this board');
    return res.json(board);
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.get('/:boardId/audit', async (req, res) => {
  const boardId = req.params.boardId;
  const limitRaw = Number(req.query?.limit ?? 100);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 500) : 100;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const role = await boardMemberRepository.getBoardRole({
      boardId,
      userId: req.auth.userId
    });
    if (!role) return forbidden(res, 'you do not have access to this board');

    const items = await auditLogRepository.listAuditLogsByBoard({ boardId, limit });
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

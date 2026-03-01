const express = require('express');
const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const listRepository = require('../repositories/listRepository');
const cardRepository = require('../repositories/cardRepository');
const { hasRequiredRole } = require('../services/authorizationService');
const { badRequest, notFound, forbidden, serverError } = require('../utils/http');

const router = express.Router();

router.get('/list/:listId', async (req, res) => {
  try {
    const list = await listRepository.getListById(req.params.listId);
    if (!list) return notFound(res, 'list not found');
    const canAccess = await boardMemberRepository.isBoardMember({
      boardId: list.boardId,
      userId: req.auth.userId
    });
    if (!canAccess) return forbidden(res, 'you do not have access to this board');

    const items = await cardRepository.listCardsByListId(list.id);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/', async (req, res) => {
  const boardId = String(req.body?.boardId || '').trim();
  const listId = String(req.body?.listId || '').trim();
  const title = String(req.body?.title || '').trim();
  const description = String(req.body?.description || '').trim();
  const orderIndex = Number(req.body?.orderIndex || 0);

  if (!boardId) return badRequest(res, 'boardId is required');
  if (!listId) return badRequest(res, 'listId is required');
  if (!title) return badRequest(res, 'title is required');
  if (!Number.isFinite(orderIndex)) return badRequest(res, 'orderIndex must be a number');

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');
    const role = await boardMemberRepository.getBoardRole({
      boardId,
      userId: req.auth.userId
    });
    if (!hasRequiredRole(role, 'editor')) {
      return forbidden(res, 'editor or owner role is required for this action');
    }

    const list = await listRepository.getListById(listId);
    if (!list) return notFound(res, 'list not found');
    if (list.boardId !== boardId) return badRequest(res, 'list does not belong to board');

    const card = await cardRepository.createCard({
      boardId,
      listId,
      title,
      description,
      orderIndex
    });
    return res.status(201).json(card);
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.patch('/:cardId', async (req, res) => {
  const cardId = req.params.cardId;
  const patch = {};

  if (typeof req.body?.title === 'string') patch.title = req.body.title.trim();
  if (typeof req.body?.description === 'string') patch.description = req.body.description.trim();
  if (typeof req.body?.listId === 'string') patch.listId = req.body.listId.trim();
  if (typeof req.body?.orderIndex !== 'undefined') {
    patch.orderIndex = Number(req.body.orderIndex);
    if (!Number.isFinite(patch.orderIndex)) return badRequest(res, 'orderIndex must be a number');
  }

  try {
    const current = await cardRepository.getCardById(cardId);
    if (!current) return notFound(res, 'card not found');
    const role = await boardMemberRepository.getBoardRole({
      boardId: current.boardId,
      userId: req.auth.userId
    });
    if (!hasRequiredRole(role, 'editor')) {
      return forbidden(res, 'editor or owner role is required for this action');
    }

    if (patch.listId) {
      const nextList = await listRepository.getListById(patch.listId);
      if (!nextList) return notFound(res, 'target list not found');
      if (nextList.boardId !== current.boardId) {
        return badRequest(res, 'target list must belong to the same board');
      }
    }

    const updated = await cardRepository.updateCard(cardId, patch);
    if (!updated) return notFound(res, 'card not found');

    return res.json(updated);
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

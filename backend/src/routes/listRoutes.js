const express = require('express');
const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const listRepository = require('../repositories/listRepository');
const { hasRequiredRole } = require('../services/authorizationService');
const { parseListCreateBody } = require('../validation/requestValidation');
const { badRequest, notFound, forbidden, serverError } = require('../utils/http');

const router = express.Router();

router.get('/board/:boardId', async (req, res) => {
  try {
    const boardId = req.params.boardId;
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');
    const canAccess = await boardMemberRepository.isBoardMember({
      boardId,
      userId: req.auth.userId
    });
    if (!canAccess) return forbidden(res, 'you do not have access to this board');

    const items = await listRepository.listListsByBoardId(board.id);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/', async (req, res) => {
  const parsed = parseListCreateBody(req.body);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { boardId, title, orderIndex } = parsed.value;

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

    const list = await listRepository.createList({ boardId, title, orderIndex });
    return res.status(201).json(list);
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

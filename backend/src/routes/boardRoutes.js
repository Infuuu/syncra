const express = require('express');
const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const auditLogRepository = require('../repositories/auditLogRepository');
const noteRepository = require('../repositories/noteRepository');
const env = require('../config/env');
const {
  parseBoardCreateBody,
  parseBoardAuditQuery,
  parseBoardNotesQuery
} = require('../validation/requestValidation');
const { badRequest, notFound, forbidden, serverError } = require('../utils/http');

const router = express.Router();

const encodeNotesCursor = ({ updatedAt, id }) =>
  Buffer.from(JSON.stringify({ updatedAt, id }), 'utf8').toString('base64url');

const decodeNotesCursor = (rawCursor) => {
  try {
    const decoded = JSON.parse(Buffer.from(rawCursor, 'base64url').toString('utf8'));
    if (!decoded || typeof decoded !== 'object') return null;
    const updatedAt = new Date(decoded.updatedAt);
    if (Number.isNaN(updatedAt.getTime())) return null;
    if (typeof decoded.id !== 'string' || !decoded.id.trim()) return null;
    return {
      updatedAt: updatedAt.toISOString(),
      id: decoded.id.trim()
    };
  } catch (_error) {
    return null;
  }
};

router.get('/', async (req, res) => {
  try {
    const items = await boardRepository.listBoardsForUser(req.auth.userId);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/', async (req, res) => {
  const parsed = parseBoardCreateBody(req.body);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { name } = parsed.value;

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
  const parsed = parseBoardAuditQuery(req.query);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { limit } = parsed.value;

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

router.get('/:boardId/notes', async (req, res) => {
  if (!env.notesEnabled) return notFound(res, 'notes feature is disabled');

  const boardId = req.params.boardId;
  const parsed = parseBoardNotesQuery(req.query);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { limit, offset, cursor } = parsed.value;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const role = await boardMemberRepository.getBoardRole({
      boardId,
      userId: req.auth.userId
    });
    if (!role) return forbidden(res, 'you do not have access to this board');

    let decodedCursor = null;
    if (cursor) {
      decodedCursor = decodeNotesCursor(cursor);
      if (!decodedCursor) return badRequest(res, 'cursor is invalid');
    }

    const items = await noteRepository.listBoardNotes({
      boardId,
      limit: limit + 1,
      offset: decodedCursor ? 0 : offset,
      cursor: decodedCursor
    });

    const hasMore = items.length > limit;
    const pageItems = hasMore ? items.slice(0, limit) : items;
    const last = pageItems[pageItems.length - 1];
    const nextCursor = hasMore && last ? encodeNotesCursor({ updatedAt: last.updatedAt, id: last.id }) : null;

    return res.json({
      items: pageItems,
      pagination: {
        limit,
        offset: decodedCursor ? null : offset,
        cursor: cursor || null,
        nextCursor
      }
    });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.get('/:boardId/notes/:noteId', async (req, res) => {
  if (!env.notesEnabled) return notFound(res, 'notes feature is disabled');

  const boardId = req.params.boardId;
  const noteId = req.params.noteId;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const role = await boardMemberRepository.getBoardRole({
      boardId,
      userId: req.auth.userId
    });
    if (!role) return forbidden(res, 'you do not have access to this board');

    const note = await noteRepository.getNoteById({ noteId });
    if (!note || note.boardId !== boardId || note.isDeleted) {
      return notFound(res, 'note not found');
    }

    return res.json(note);
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

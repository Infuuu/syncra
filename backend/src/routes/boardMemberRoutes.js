const express = require('express');

const boardRepository = require('../repositories/boardRepository');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const userRepository = require('../repositories/userRepository');
const auditLogRepository = require('../repositories/auditLogRepository');
const { hasRequiredRole } = require('../services/authorizationService');
const {
  parseBoardMemberUpsertBody,
  parseBoardMemberRolePatchBody
} = require('../validation/requestValidation');
const { badRequest, notFound, forbidden, serverError } = require('../utils/http');

const router = express.Router({ mergeParams: true });

router.get('/', async (req, res) => {
  const boardId = req.params.boardId;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const role = await boardMemberRepository.getBoardRole({ boardId, userId: req.auth.userId });
    if (!role) return forbidden(res, 'you do not have access to this board');

    const items = await boardMemberRepository.listBoardMembers(boardId);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/', async (req, res) => {
  const boardId = req.params.boardId;
  const parsed = parseBoardMemberUpsertBody(req.body);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { email, role } = parsed.value;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const actorRole = await boardMemberRepository.getBoardRole({ boardId, userId: req.auth.userId });
    if (!hasRequiredRole(actorRole, 'owner')) {
      return forbidden(res, 'only owner can add members');
    }

    const user = await userRepository.getUserByEmail(email);
    if (!user) return notFound(res, 'user with this email does not exist');

    const existingRole = await boardMemberRepository.getBoardRole({ boardId, userId: user.id });
    await boardMemberRepository.addBoardMember({ boardId, userId: user.id, role });
    if (existingRole !== role) {
      await auditLogRepository.createAuditLog({
        actorUserId: req.auth.userId,
        boardId,
        eventType: existingRole ? 'board.member_role_updated' : 'board.member_added',
        entityType: 'board_member',
        entityId: user.id,
        metadata: {
          previousRole: existingRole,
          nextRole: role
        }
      });
    }
    const items = await boardMemberRepository.listBoardMembers(boardId);
    return res.status(201).json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.patch('/:userId', async (req, res) => {
  const boardId = req.params.boardId;
  const targetUserId = req.params.userId;
  const parsed = parseBoardMemberRolePatchBody(req.body);
  if (!parsed.ok) return badRequest(res, parsed.error);
  const { role } = parsed.value;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const actorRole = await boardMemberRepository.getBoardRole({ boardId, userId: req.auth.userId });
    if (!hasRequiredRole(actorRole, 'owner')) {
      return forbidden(res, 'only owner can change member roles');
    }

    const targetRole = await boardMemberRepository.getBoardRole({ boardId, userId: targetUserId });
    if (!targetRole) return notFound(res, 'board member not found');

    if (targetRole === 'owner' && role !== 'owner') {
      const ownerCount = await boardMemberRepository.countBoardOwners(boardId);
      if (ownerCount <= 1) return badRequest(res, 'board must have at least one owner');
    }

    await boardMemberRepository.updateBoardMemberRole({ boardId, userId: targetUserId, role });
    if (targetRole !== role) {
      await auditLogRepository.createAuditLog({
        actorUserId: req.auth.userId,
        boardId,
        eventType: 'board.member_role_updated',
        entityType: 'board_member',
        entityId: targetUserId,
        metadata: {
          previousRole: targetRole,
          nextRole: role
        }
      });
    }
    const items = await boardMemberRepository.listBoardMembers(boardId);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.delete('/:userId', async (req, res) => {
  const boardId = req.params.boardId;
  const targetUserId = req.params.userId;

  try {
    const board = await boardRepository.getBoardById(boardId);
    if (!board) return notFound(res, 'board not found');

    const actorRole = await boardMemberRepository.getBoardRole({ boardId, userId: req.auth.userId });
    if (!hasRequiredRole(actorRole, 'owner')) {
      return forbidden(res, 'only owner can remove members');
    }

    const targetRole = await boardMemberRepository.getBoardRole({ boardId, userId: targetUserId });
    if (!targetRole) return notFound(res, 'board member not found');

    if (targetRole === 'owner') {
      const ownerCount = await boardMemberRepository.countBoardOwners(boardId);
      if (ownerCount <= 1) return badRequest(res, 'board must have at least one owner');
    }

    await boardMemberRepository.removeBoardMember({ boardId, userId: targetUserId });
    await auditLogRepository.createAuditLog({
      actorUserId: req.auth.userId,
      boardId,
      eventType: 'board.member_removed',
      entityType: 'board_member',
      entityId: targetUserId,
      metadata: {
        removedRole: targetRole
      }
    });
    const items = await boardMemberRepository.listBoardMembers(boardId);
    return res.json({ items });
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

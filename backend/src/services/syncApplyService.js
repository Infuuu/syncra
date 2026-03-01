const env = require('../config/env');

class SyncApplyError extends Error {
  constructor(message, statusCode = 400, errorCode = null) {
    super(message);
    this.name = 'SyncApplyError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
  }
}

class SyncApplyConflictError extends SyncApplyError {
  constructor(message, snapshot, errorCode = 'version_conflict') {
    super(message, 409, errorCode);
    this.name = 'SyncApplyConflictError';
    this.snapshot = snapshot;
  }
}

const normalizeAction = (operationType) => {
  const value = String(operationType || '').trim().toLowerCase();
  const action = value.includes('.') ? value.split('.').pop() : value;

  if (action === 'create') return 'created';
  if (action === 'update') return 'updated';
  if (action === 'delete') return 'deleted';
  if (action === 'move') return 'moved';

  return action;
};

const requireStringField = (payload, fieldName) => {
  const value = typeof payload?.[fieldName] === 'string' ? payload[fieldName].trim() : '';
  if (!value) throw new SyncApplyError(`${fieldName} is required`, 400);
  return value;
};

const parseExpectedVersion = (payload, context) => {
  const value = payload?.expectedVersion;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new SyncApplyError(`payload.expectedVersion is required for ${context} and must be a positive integer`, 400);
  }
  return parsed;
};

const getBoardSnapshot = async (client, boardId) => {
  const { rows } = await client.query(
    'SELECT id, name, version, is_deleted, deleted_at, created_at, updated_at FROM boards WHERE id = $1',
    [boardId]
  );
  if (!rows[0]) return null;
  return {
    entityType: 'board',
    entity: {
      id: rows[0].id,
      name: rows[0].name,
      version: Number(rows[0].version),
      isDeleted: rows[0].is_deleted,
      deletedAt: rows[0].deleted_at,
      createdAt: rows[0].created_at,
      updatedAt: rows[0].updated_at
    }
  };
};

const getListSnapshot = async (client, boardId, listId) => {
  const { rows } = await client.query(
    `SELECT id, board_id, title, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM lists
     WHERE id = $1::uuid AND board_id = $2::uuid`,
    [listId, boardId]
  );
  if (!rows[0]) return null;
  return {
    entityType: 'list',
    entity: {
      id: rows[0].id,
      boardId: rows[0].board_id,
      title: rows[0].title,
      orderIndex: rows[0].order_index,
      version: Number(rows[0].version),
      isDeleted: rows[0].is_deleted,
      deletedAt: rows[0].deleted_at,
      createdAt: rows[0].created_at,
      updatedAt: rows[0].updated_at
    }
  };
};

const getCardSnapshot = async (client, boardId, cardId) => {
  const { rows } = await client.query(
    `SELECT id, board_id, list_id, title, description, order_index, version, is_deleted, deleted_at, created_at, updated_at
     FROM cards
     WHERE id = $1::uuid AND board_id = $2::uuid`,
    [cardId, boardId]
  );
  if (!rows[0]) return null;
  return {
    entityType: 'card',
    entity: {
      id: rows[0].id,
      boardId: rows[0].board_id,
      listId: rows[0].list_id,
      title: rows[0].title,
      description: rows[0].description,
      orderIndex: rows[0].order_index,
      version: Number(rows[0].version),
      isDeleted: rows[0].is_deleted,
      deletedAt: rows[0].deleted_at,
      createdAt: rows[0].created_at,
      updatedAt: rows[0].updated_at
    }
  };
};

const getNoteSnapshot = async (client, boardId, noteId) => {
  const { rows } = await client.query(
    `SELECT id, board_id, created_by, title, content, version, is_deleted, deleted_at, created_at, updated_at
     FROM notes
     WHERE id = $1::uuid AND board_id = $2::uuid`,
    [noteId, boardId]
  );
  if (!rows[0]) return null;
  return {
    entityType: 'note',
    entity: {
      id: rows[0].id,
      boardId: rows[0].board_id,
      createdBy: rows[0].created_by,
      title: rows[0].title,
      content: rows[0].content,
      version: Number(rows[0].version),
      isDeleted: rows[0].is_deleted,
      deletedAt: rows[0].deleted_at,
      createdAt: rows[0].created_at,
      updatedAt: rows[0].updated_at
    }
  };
};

const applyBoardOperation = async (client, operation) => {
  const action = normalizeAction(operation.operationType);
  const boardId = operation.boardId;
  const payload = operation.payload || {};

  if (action === 'created') {
    throw new SyncApplyError(
      'board.created is not supported via sync/push; create boards with POST /api/boards',
      400
    );
  }

  if (action === 'updated') {
    const expectedVersion = parseExpectedVersion(payload, 'board update');
    if (typeof payload.name !== 'string' || !payload.name.trim()) {
      throw new SyncApplyError('payload.name is required for board update', 400);
    }

    const { rowCount } = await client.query(
      `UPDATE boards
       SET name = $2, version = version + 1, updated_at = now()
       WHERE id = $1 AND version = $3 AND is_deleted = FALSE`,
      [boardId, payload.name.trim(), expectedVersion]
    );

    if (rowCount === 0) {
      const snapshot = await getBoardSnapshot(client, boardId);
      if (!snapshot) throw new SyncApplyError('board not found', 404);
      throw new SyncApplyConflictError('board version conflict', snapshot);
    }
    return;
  }

  if (action === 'deleted') {
    const expectedVersion = parseExpectedVersion(payload, 'board delete');
    const { rowCount } = await client.query(
      `UPDATE boards
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE id = $1 AND version = $2 AND is_deleted = FALSE`,
      [boardId, expectedVersion]
    );
    if (rowCount === 0) {
      const snapshot = await getBoardSnapshot(client, boardId);
      if (!snapshot) throw new SyncApplyError('board not found', 404);
      throw new SyncApplyConflictError('board version conflict', snapshot);
    }
    await client.query(
      `UPDATE lists
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE board_id = $1 AND is_deleted = FALSE`,
      [boardId]
    );
    await client.query(
      `UPDATE cards
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE board_id = $1 AND is_deleted = FALSE`,
      [boardId]
    );
    await client.query(
      `UPDATE notes
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE board_id = $1 AND is_deleted = FALSE`,
      [boardId]
    );
    return;
  }

  throw new SyncApplyError(`unsupported board operation action: ${action}`, 400);
};

const applyListOperation = async (client, operation) => {
  const action = normalizeAction(operation.operationType);
  const boardId = operation.boardId;
  const listId = operation.entityId;
  const payload = operation.payload || {};

  if (action === 'created') {
    const boardCheck = await client.query(
      'SELECT 1 FROM boards WHERE id = $1::uuid AND is_deleted = FALSE LIMIT 1',
      [boardId]
    );
    if (boardCheck.rowCount === 0) {
      throw new SyncApplyError('board not found', 404);
    }

    const title = requireStringField(payload, 'title');
    const orderIndex = Number.isFinite(Number(payload.orderIndex)) ? Number(payload.orderIndex) : 0;

    try {
      await client.query(
        `INSERT INTO lists (id, board_id, title, order_index, updated_at)
         VALUES ($1::uuid, $2::uuid, $3, $4, now())`,
        [listId, boardId, title, orderIndex]
      );
    } catch (error) {
      if (error && error.code === '23505') {
        const snapshot = await getListSnapshot(client, boardId, listId);
        throw new SyncApplyConflictError('list already exists', snapshot);
      }
      throw error;
    }
    return;
  }

  if (action === 'updated' || action === 'moved') {
    const expectedVersion = parseExpectedVersion(payload, 'list update');
    const updates = [];
    const values = [listId, boardId];

    if (typeof payload.title === 'string' && payload.title.trim()) {
      values.push(payload.title.trim());
      updates.push(`title = $${values.length}`);
    }

    if (typeof payload.orderIndex !== 'undefined') {
      const orderIndex = Number(payload.orderIndex);
      if (!Number.isFinite(orderIndex)) {
        throw new SyncApplyError('payload.orderIndex must be a number', 400);
      }
      values.push(orderIndex);
      updates.push(`order_index = $${values.length}`);
    }

    if (updates.length === 0) {
      throw new SyncApplyError('no updatable fields provided for list operation', 400);
    }

    values.push(expectedVersion);
    const versionIndex = values.length;

    const { rowCount } = await client.query(
      `UPDATE lists
       SET ${updates.join(', ')}, version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $${versionIndex} AND is_deleted = FALSE`,
      values
    );

    if (rowCount === 0) {
      const snapshot = await getListSnapshot(client, boardId, listId);
      if (!snapshot) throw new SyncApplyError('list not found', 404);
      throw new SyncApplyConflictError('list version conflict', snapshot);
    }
    return;
  }

  if (action === 'deleted') {
    const expectedVersion = parseExpectedVersion(payload, 'list delete');
    const { rowCount } = await client.query(
      `UPDATE lists
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $3 AND is_deleted = FALSE`,
      [listId, boardId, expectedVersion]
    );

    if (rowCount === 0) {
      const snapshot = await getListSnapshot(client, boardId, listId);
      if (!snapshot) throw new SyncApplyError('list not found', 404);
      throw new SyncApplyConflictError('list version conflict', snapshot);
    }
    await client.query(
      `UPDATE cards
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE list_id = $1::uuid AND board_id = $2::uuid AND is_deleted = FALSE`,
      [listId, boardId]
    );
    return;
  }

  throw new SyncApplyError(`unsupported list operation action: ${action}`, 400);
};

const applyCardOperation = async (client, operation) => {
  const action = normalizeAction(operation.operationType);
  const boardId = operation.boardId;
  const cardId = operation.entityId;
  const payload = operation.payload || {};

  if (action === 'created') {
    const listId = requireStringField(payload, 'listId');
    const title = requireStringField(payload, 'title');
    const description = typeof payload.description === 'string' ? payload.description : '';
    const orderIndex = Number.isFinite(Number(payload.orderIndex)) ? Number(payload.orderIndex) : 0;

    const listCheck = await client.query(
      'SELECT 1 FROM lists WHERE id = $1::uuid AND board_id = $2::uuid AND is_deleted = FALSE LIMIT 1',
      [listId, boardId]
    );
    if (listCheck.rowCount === 0) {
      throw new SyncApplyError('list not found for card creation', 404);
    }

    try {
      await client.query(
        `INSERT INTO cards (id, board_id, list_id, title, description, order_index, updated_at)
         VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, now())`,
        [cardId, boardId, listId, title, description, orderIndex]
      );
    } catch (error) {
      if (error && error.code === '23505') {
        const snapshot = await getCardSnapshot(client, boardId, cardId);
        throw new SyncApplyConflictError('card already exists', snapshot);
      }
      throw error;
    }
    return;
  }

  if (action === 'updated' || action === 'moved') {
    const expectedVersion = parseExpectedVersion(payload, 'card update');
    const updates = [];
    const values = [cardId, boardId];

    if (typeof payload.title === 'string' && payload.title.trim()) {
      values.push(payload.title.trim());
      updates.push(`title = $${values.length}`);
    }

    if (typeof payload.description === 'string') {
      values.push(payload.description);
      updates.push(`description = $${values.length}`);
    }

    if (typeof payload.orderIndex !== 'undefined') {
      const orderIndex = Number(payload.orderIndex);
      if (!Number.isFinite(orderIndex)) {
        throw new SyncApplyError('payload.orderIndex must be a number', 400);
      }
      values.push(orderIndex);
      updates.push(`order_index = $${values.length}`);
    }

    if (typeof payload.listId === 'string' && payload.listId.trim()) {
      const listId = payload.listId.trim();
      const listCheck = await client.query(
        'SELECT 1 FROM lists WHERE id = $1::uuid AND board_id = $2::uuid AND is_deleted = FALSE LIMIT 1',
        [listId, boardId]
      );
      if (listCheck.rowCount === 0) {
        throw new SyncApplyError('target list not found in board', 404);
      }

      values.push(listId);
      updates.push(`list_id = $${values.length}::uuid`);
    }

    if (updates.length === 0) {
      throw new SyncApplyError('no updatable fields provided for card operation', 400);
    }

    values.push(expectedVersion);
    const versionIndex = values.length;

    const { rowCount } = await client.query(
      `UPDATE cards
       SET ${updates.join(', ')}, version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $${versionIndex} AND is_deleted = FALSE`,
      values
    );

    if (rowCount === 0) {
      const snapshot = await getCardSnapshot(client, boardId, cardId);
      if (!snapshot) throw new SyncApplyError('card not found', 404);
      throw new SyncApplyConflictError('card version conflict', snapshot);
    }
    return;
  }

  if (action === 'deleted') {
    const expectedVersion = parseExpectedVersion(payload, 'card delete');
    const { rowCount } = await client.query(
      `UPDATE cards
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $3 AND is_deleted = FALSE`,
      [cardId, boardId, expectedVersion]
    );

    if (rowCount === 0) {
      const snapshot = await getCardSnapshot(client, boardId, cardId);
      if (!snapshot) throw new SyncApplyError('card not found', 404);
      throw new SyncApplyConflictError('card version conflict', snapshot);
    }
    return;
  }

  throw new SyncApplyError(`unsupported card operation action: ${action}`, 400);
};

const applyNoteOperation = async (client, operation) => {
  const action = normalizeAction(operation.operationType);
  const boardId = operation.boardId;
  const noteId = operation.entityId;
  const payload = operation.payload || {};

  if (action === 'created') {
    const boardCheck = await client.query(
      'SELECT 1 FROM boards WHERE id = $1::uuid AND is_deleted = FALSE LIMIT 1',
      [boardId]
    );
    if (boardCheck.rowCount === 0) {
      throw new SyncApplyError('board not found', 404);
    }

    const title = typeof payload.title === 'string' ? payload.title.trim() : '';
    const content = payload.content;

    try {
      await client.query(
        `INSERT INTO notes (id, board_id, created_by, title, content, updated_at)
         VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5::jsonb, now())`,
        [noteId, boardId, operation.actorUserId, title, JSON.stringify(content)]
      );
    } catch (error) {
      if (error && error.code === '23505') {
        const snapshot = await getNoteSnapshot(client, boardId, noteId);
        throw new SyncApplyConflictError('note already exists', snapshot);
      }
      throw error;
    }
    return;
  }

  if (action === 'updated') {
    const expectedVersion = parseExpectedVersion(payload, 'note update');
    const title = typeof payload.title === 'string' ? payload.title.trim() : '';

    const { rowCount } = await client.query(
      `UPDATE notes
       SET title = $3, content = $4::jsonb, version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $5 AND is_deleted = FALSE`,
      [noteId, boardId, title, JSON.stringify(payload.content), expectedVersion]
    );

    if (rowCount === 0) {
      const snapshot = await getNoteSnapshot(client, boardId, noteId);
      if (!snapshot) throw new SyncApplyError('note not found', 404);
      throw new SyncApplyConflictError('note version conflict', snapshot);
    }
    return;
  }

  if (action === 'deleted') {
    const expectedVersion = parseExpectedVersion(payload, 'note delete');
    const { rowCount } = await client.query(
      `UPDATE notes
       SET is_deleted = TRUE, deleted_at = now(), version = version + 1, updated_at = now()
       WHERE id = $1::uuid AND board_id = $2::uuid AND version = $3 AND is_deleted = FALSE`,
      [noteId, boardId, expectedVersion]
    );

    if (rowCount === 0) {
      const snapshot = await getNoteSnapshot(client, boardId, noteId);
      if (!snapshot) throw new SyncApplyError('note not found', 404);
      throw new SyncApplyConflictError('note version conflict', snapshot);
    }
    return;
  }

  throw new SyncApplyError(`unsupported note operation action: ${action}`, 400);
};

const applySyncOperationToCanonicalTables = async (client, operation) => {
  const entityType = String(operation.entityType || '').trim().toLowerCase();

  if (entityType === 'board') return applyBoardOperation(client, operation);
  if (entityType === 'list') return applyListOperation(client, operation);
  if (entityType === 'card') return applyCardOperation(client, operation);
  if (entityType === 'note') {
    if (!env.notesEnabled) {
      throw new SyncApplyError('notes feature is disabled', 400);
    }
    return applyNoteOperation(client, operation);
  }

  throw new SyncApplyError(`unsupported entityType: ${operation.entityType}`, 400);
};

module.exports = {
  SyncApplyError,
  SyncApplyConflictError,
  applySyncOperationToCanonicalTables
};

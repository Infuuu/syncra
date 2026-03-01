const { SyncApplyError } = require('./syncApplyService');
const env = require('../config/env');

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const toAction = (operationType) => {
  const value = String(operationType || '').trim().toLowerCase();
  const action = value.includes('.') ? value.split('.').pop() : value;

  if (action === 'create') return 'created';
  if (action === 'update') return 'updated';
  if (action === 'delete') return 'deleted';
  if (action === 'move') return 'moved';
  return action;
};

const isUuid = (value) => UUID_RE.test(String(value || '').trim());

const requireUuid = (value, fieldName) => {
  if (!isUuid(value)) {
    throw new SyncApplyError(`${fieldName} must be a valid UUID`, 400);
  }
};

const requireString = (payload, fieldName) => {
  const value = typeof payload?.[fieldName] === 'string' ? payload[fieldName].trim() : '';
  if (!value) {
    throw new SyncApplyError(`payload.${fieldName} is required`, 400);
  }
};

const requireNumberIfProvided = (payload, fieldName) => {
  if (typeof payload?.[fieldName] === 'undefined') return;
  const value = Number(payload[fieldName]);
  if (!Number.isFinite(value)) {
    throw new SyncApplyError(`payload.${fieldName} must be a number`, 400);
  }
};

const requireExpectedVersionForMutations = (payload, action) => {
  if (action === 'updated' || action === 'moved' || action === 'deleted') {
    const expected = Number(payload?.expectedVersion);
    if (!Number.isInteger(expected) || expected < 1) {
      throw new SyncApplyError(
        `payload.expectedVersion is required for ${action} operations and must be a positive integer`,
        400
      );
    }
  }
};

const requireWithinByteLimit = (payload, fieldName, maxBytes) => {
  const value = payload?.[fieldName];
  const bytes = Buffer.byteLength(JSON.stringify(value || {}), 'utf8');
  if (bytes > maxBytes) {
    throw new SyncApplyError(`payload.${fieldName} exceeds max size of ${maxBytes} bytes`, 400);
  }
};

const normalizeNoteSchemaVersion = (payload) => {
  if (typeof payload?.schemaVersion === 'undefined') {
    return env.noteDocSchemaVersion;
  }

  const parsed = Number(payload.schemaVersion);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new SyncApplyError(
      'payload.schemaVersion must be a positive integer when provided',
      400,
      'note_schema_version_invalid'
    );
  }
  return parsed;
};

const validateRichTextContent = (payload, fieldName) => {
  const value = payload?.[fieldName];
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new SyncApplyError(`payload.${fieldName} must be an object`, 400, 'note_content_invalid');
  }

  if (value.type !== 'doc') {
    throw new SyncApplyError(`payload.${fieldName}.type must be "doc"`, 400, 'note_content_invalid');
  }

  if (!Array.isArray(value.content)) {
    throw new SyncApplyError(
      `payload.${fieldName}.content must be an array`,
      400,
      'note_content_invalid'
    );
  }
};

const validateOperationByEntity = ({ entityType, action, payload, operationType }) => {
  if (entityType === 'board') {
    if (!['created', 'updated', 'deleted'].includes(action)) {
      throw new SyncApplyError(`unsupported board operation action: ${action}`, 400);
    }

    if (action === 'updated') {
      requireString(payload, 'name');
    }

    requireExpectedVersionForMutations(payload, action);
    return;
  }

  if (entityType === 'list') {
    if (!['created', 'updated', 'moved', 'deleted'].includes(action)) {
      throw new SyncApplyError(`unsupported list operation action: ${action}`, 400);
    }

    if (action === 'created') {
      requireString(payload, 'title');
      requireNumberIfProvided(payload, 'orderIndex');
    }

    if (action === 'updated' || action === 'moved') {
      const hasTitle = typeof payload?.title === 'string' && payload.title.trim().length > 0;
      const hasOrderIndex = typeof payload?.orderIndex !== 'undefined';
      if (!hasTitle && !hasOrderIndex) {
        throw new SyncApplyError('payload.title or payload.orderIndex is required for list update/move', 400);
      }
      requireNumberIfProvided(payload, 'orderIndex');
    }

    requireExpectedVersionForMutations(payload, action);
    return;
  }

  if (entityType === 'card') {
    if (!['created', 'updated', 'moved', 'deleted'].includes(action)) {
      throw new SyncApplyError(`unsupported card operation action: ${action}`, 400);
    }

    if (action === 'created') {
      requireString(payload, 'listId');
      requireUuid(payload.listId, 'payload.listId');
      requireString(payload, 'title');
      requireNumberIfProvided(payload, 'orderIndex');
    }

    if (action === 'updated' || action === 'moved') {
      const hasTitle = typeof payload?.title === 'string' && payload.title.trim().length > 0;
      const hasDescription = typeof payload?.description === 'string';
      const hasOrderIndex = typeof payload?.orderIndex !== 'undefined';
      const hasListId = typeof payload?.listId === 'string' && payload.listId.trim().length > 0;
      if (!hasTitle && !hasDescription && !hasOrderIndex && !hasListId) {
        throw new SyncApplyError(
          'at least one of payload.title, payload.description, payload.orderIndex, payload.listId is required for card update/move',
          400
        );
      }
      if (hasListId) {
        requireUuid(payload.listId, 'payload.listId');
      }
      requireNumberIfProvided(payload, 'orderIndex');
    }

    requireExpectedVersionForMutations(payload, action);
    return;
  }

  if (entityType === 'note') {
    if (!env.notesEnabled) {
      throw new SyncApplyError('notes feature is disabled', 400, 'notes_feature_disabled');
    }

    if (!['created', 'updated', 'deleted'].includes(action)) {
      throw new SyncApplyError(`unsupported note operation action: ${action}`, 400);
    }

    if (action === 'created' || action === 'updated') {
      if (typeof payload?.title !== 'string') {
        throw new SyncApplyError('payload.title is required and must be a string', 400);
      }

      const schemaVersion = normalizeNoteSchemaVersion(payload);
      if (schemaVersion !== env.noteDocSchemaVersion) {
        throw new SyncApplyError(
          `payload.schemaVersion ${schemaVersion} is not supported; expected ${env.noteDocSchemaVersion}`,
          400,
          'note_schema_version_unsupported'
        );
      }

      validateRichTextContent(payload, 'content');
      requireWithinByteLimit(payload, 'content', env.noteContentMaxBytes);
    }

    requireExpectedVersionForMutations(payload, action);
    return;
  }

  throw new SyncApplyError(`unsupported entityType: ${entityType}`, 400);
};

const validateSyncPushOperation = (operation) => {
  requireUuid(operation.boardId, 'boardId');

  const entityType = String(operation.entityType || '').trim().toLowerCase();
  const action = toAction(operation.operationType);
  const payload = operation.payload && typeof operation.payload === 'object' ? operation.payload : {};

  if (!['board', 'list', 'card', 'note'].includes(entityType)) {
    throw new SyncApplyError(`unsupported entityType: ${operation.entityType}`, 400);
  }

  if (!action) {
    throw new SyncApplyError(`unsupported operationType: ${operation.operationType}`, 400);
  }

  if (entityType === 'board' || entityType === 'list' || entityType === 'card' || entityType === 'note') {
    requireUuid(operation.entityId, 'entityId');
  }

  validateOperationByEntity({ entityType, action, payload, operationType: operation.operationType });
};

module.exports = {
  validateSyncPushOperation
};

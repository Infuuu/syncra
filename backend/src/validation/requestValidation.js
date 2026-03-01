const BOARD_ROLES = new Set(['viewer', 'editor', 'owner']);

const resultOk = (value) => ({ ok: true, value });
const resultError = (error) => ({ ok: false, error });

const asTrimmedString = (value) =>
  typeof value === 'string' ? value.trim() : String(value || '').trim();

const parseRequiredString = (value, message) => {
  const parsed = asTrimmedString(value);
  if (!parsed) return resultError(message);
  return resultOk(parsed);
};

const parseOptionalString = (value) => {
  if (typeof value === 'undefined' || value === null) return resultOk(undefined);
  if (typeof value !== 'string') return resultError('must be a string');
  return resultOk(value.trim());
};

const parseNumber = (value, message) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return resultError(message);
  return resultOk(parsed);
};

const parsePositiveInt = (value, message) => {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) return resultError(message);
  return resultOk(parsed);
};

const parseEmail = (value) => {
  const email = asTrimmedString(value).toLowerCase();
  if (!email) return resultError('email is required');
  const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  if (!isEmail) return resultError('email must be a valid email address');
  return resultOk(email);
};

const parseRole = (value) => {
  const role = asTrimmedString(value).toLowerCase();
  if (!BOARD_ROLES.has(role)) {
    return resultError('role must be one of: viewer, editor, owner');
  }
  return resultOk(role);
};

const parseAuthRegisterBody = (body) => {
  const email = parseEmail(body?.email);
  if (!email.ok) return email;

  const password = asTrimmedString(body?.password || '');
  if (!password) return resultError('password is required');
  if (password.length < 8) return resultError('password must be at least 8 characters');

  const displayName = parseRequiredString(body?.displayName, 'displayName is required');
  if (!displayName.ok) return displayName;

  return resultOk({
    email: email.value,
    password,
    displayName: displayName.value
  });
};

const parseAuthLoginBody = (body) => {
  const email = parseEmail(body?.email);
  if (!email.ok) return email;
  const password = asTrimmedString(body?.password || '');
  if (!password) return resultError('password is required');
  return resultOk({ email: email.value, password });
};

const parseRefreshTokenBody = (body) => {
  const refreshToken = parseRequiredString(body?.refreshToken, 'refreshToken is required');
  if (!refreshToken.ok) return refreshToken;
  return resultOk({ refreshToken: refreshToken.value });
};

const parseBoardCreateBody = (body) => {
  const name = parseRequiredString(body?.name, 'name is required');
  if (!name.ok) return name;
  return resultOk({ name: name.value });
};

const parseBoardAuditQuery = (query) => {
  const limitRaw = Number(query?.limit ?? 100);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 500) : 100;
  return resultOk({ limit });
};

const parseBoardNotesQuery = (query) => {
  const limitRaw = Number(query?.limit ?? 100);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 500) : 100;

  const hasCursor = typeof query?.cursor === 'string' && query.cursor.trim().length > 0;
  const hasOffset = typeof query?.offset !== 'undefined';
  if (hasCursor && hasOffset) {
    return resultError('offset cannot be used with cursor');
  }

  if (hasCursor) {
    return resultOk({
      limit,
      cursor: query.cursor.trim(),
      offset: null
    });
  }

  const offsetRaw = Number(query?.offset ?? 0);
  if (!Number.isInteger(offsetRaw) || offsetRaw < 0) {
    return resultError('offset must be a non-negative integer');
  }

  return resultOk({ limit, offset: offsetRaw, cursor: null });
};

const parseBoardMemberUpsertBody = (body) => {
  const email = parseEmail(body?.email);
  if (!email.ok) return email;
  const role = parseRole(body?.role);
  if (!role.ok) return role;
  return resultOk({ email: email.value, role: role.value });
};

const parseBoardMemberRolePatchBody = (body) => {
  const role = parseRole(body?.role);
  if (!role.ok) return role;
  return resultOk({ role: role.value });
};

const parseListCreateBody = (body) => {
  const boardId = parseRequiredString(body?.boardId, 'boardId is required');
  if (!boardId.ok) return boardId;
  const title = parseRequiredString(body?.title, 'title is required');
  if (!title.ok) return title;
  const orderIndex = parseNumber(body?.orderIndex ?? 0, 'orderIndex must be a number');
  if (!orderIndex.ok) return orderIndex;
  return resultOk({
    boardId: boardId.value,
    title: title.value,
    orderIndex: orderIndex.value
  });
};

const parseCardCreateBody = (body) => {
  const boardId = parseRequiredString(body?.boardId, 'boardId is required');
  if (!boardId.ok) return boardId;
  const listId = parseRequiredString(body?.listId, 'listId is required');
  if (!listId.ok) return listId;
  const title = parseRequiredString(body?.title, 'title is required');
  if (!title.ok) return title;
  const description = typeof body?.description === 'string' ? body.description.trim() : '';
  const orderIndex = parseNumber(body?.orderIndex ?? 0, 'orderIndex must be a number');
  if (!orderIndex.ok) return orderIndex;
  return resultOk({
    boardId: boardId.value,
    listId: listId.value,
    title: title.value,
    description,
    orderIndex: orderIndex.value
  });
};

const parseCardPatchBody = (body) => {
  const patch = {};

  const title = parseOptionalString(body?.title);
  if (!title.ok) return resultError('title must be a string');
  if (typeof title.value !== 'undefined') patch.title = title.value;

  const description = parseOptionalString(body?.description);
  if (!description.ok) return resultError('description must be a string');
  if (typeof description.value !== 'undefined') patch.description = description.value;

  const listId = parseOptionalString(body?.listId);
  if (!listId.ok) return resultError('listId must be a string');
  if (typeof listId.value !== 'undefined') patch.listId = listId.value;

  if (typeof body?.orderIndex !== 'undefined') {
    const orderIndex = parseNumber(body.orderIndex, 'orderIndex must be a number');
    if (!orderIndex.ok) return orderIndex;
    patch.orderIndex = orderIndex.value;
  }

  return resultOk({ patch });
};

const parseSyncOperation = (input) => {
  const boardId = parseRequiredString(input?.boardId, 'boardId is required');
  if (!boardId.ok) return boardId;
  const operationType = parseRequiredString(input?.operationType, 'operationType is required');
  if (!operationType.ok) return operationType;
  const entityType = parseRequiredString(input?.entityType, 'entityType is required');
  if (!entityType.ok) return entityType;
  const entityId = parseRequiredString(input?.entityId, 'entityId is required');
  if (!entityId.ok) return entityId;

  const clientOperationIdRaw = input?.clientOperationId;
  const clientOperationId =
    typeof clientOperationIdRaw === 'string' && clientOperationIdRaw.trim()
      ? clientOperationIdRaw.trim()
      : null;
  const payload = input?.payload && typeof input.payload === 'object' ? input.payload : {};

  return resultOk({
    boardId: boardId.value,
    clientOperationId,
    operationType: operationType.value,
    entityType: entityType.value,
    entityId: entityId.value,
    payload
  });
};

const parseSyncPushBody = (body) => {
  const operations = Array.isArray(body?.operations) ? body.operations : null;
  if (!operations) return resultError('operations array is required');
  if (operations.length === 0) return resultError('operations must not be empty');
  if (operations.length > 100) return resultError('operations limit is 100 per request');

  const normalized = [];
  for (const raw of operations) {
    const op = parseSyncOperation(raw);
    if (!op.ok) return op;
    normalized.push(op.value);
  }

  return resultOk({ operations: normalized });
};

const parseSyncFailuresQuery = (query) => {
  const boardId = query?.boardId ? asTrimmedString(query.boardId) : null;
  const limitRaw = Number(query?.limit ?? 100);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 500) : 100;
  return resultOk({ boardId, limit });
};

const parseSyncRetryParams = (params) => {
  const failureId = parsePositiveInt(params?.failureId, 'failureId must be a positive integer');
  if (!failureId.ok) return failureId;
  return resultOk({ failureId: failureId.value });
};

const parseSyncPullQuery = (query) => {
  const sinceVersion = Number(query?.sinceVersion ?? 0);
  if (!Number.isInteger(sinceVersion) || sinceVersion < 0) {
    return resultError('sinceVersion must be a non-negative integer');
  }
  const boardId = query?.boardId ? asTrimmedString(query.boardId) : null;
  const limitRaw = Number(query?.limit ?? 500);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 1000) : 500;
  return resultOk({ sinceVersion, boardId, limit });
};

module.exports = {
  parseAuthRegisterBody,
  parseAuthLoginBody,
  parseRefreshTokenBody,
  parseBoardCreateBody,
  parseBoardAuditQuery,
  parseBoardNotesQuery,
  parseBoardMemberUpsertBody,
  parseBoardMemberRolePatchBody,
  parseListCreateBody,
  parseCardCreateBody,
  parseCardPatchBody,
  parseSyncPushBody,
  parseSyncFailuresQuery,
  parseSyncRetryParams,
  parseSyncPullQuery
};

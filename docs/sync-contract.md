# Sync API Contract

## Auth

All sync endpoints require:

```text
Authorization: Bearer <token>
```

Every HTTP response includes:

```text
x-request-id: <uuid>
```

## Capabilities

`GET /api/capabilities` exposes server-driven feature/limit/schema negotiation for clients.
For notes clients, consume:
- `features.notesEnabled`
- `schemas.noteDocSchemaVersion`
- `errorCodes` (stable machine-readable codes for sync/note errors)
- `limits.noteContentMaxBytes`

## POST /api/sync/push

Pushes client operations. Each operation is validated, authorized, logged, and applied to canonical tables in one transaction.
If any operation in the request fails, the full batch is rolled back (all-or-nothing).
Route is rate-limited and payload-size limited server-side.

### Request

```json
{
  "operations": [
    {
      "clientOperationId": "deviceA-1001",
      "boardId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "operationType": "card.updated",
      "entityType": "card",
      "entityId": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "payload": {
        "title": "Updated title",
        "expectedVersion": 3
      }
    }
  ]
}
```

### Response (201)

```json
{
  "items": [
    {
      "status": "applied",
      "clientOperationId": "deviceA-1001",
      "version": 42,
      "boardId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "operationType": "card.updated",
      "entityType": "card",
      "entityId": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "createdAt": "2026-03-01T17:00:00.000Z"
    }
  ],
  "latestVersion": 42
}
```

### Conflict response (409)

```json
{
  "error": "card version conflict",
  "errorCode": "version_conflict",
  "conflict": {
    "serverSnapshot": {
      "entityType": "card",
      "entity": {
        "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        "version": 4
      }
    }
  }
}
```

For sync apply failures (`4xx` from `/api/sync/push` and retry endpoint), responses include:
- `error` (human-readable)
- `errorCode` (machine-readable, stable for client branching)

Example note-related codes:
- `notes_feature_disabled`
- `note_schema_version_invalid`
- `note_schema_version_unsupported`
- `note_content_invalid`

## GET /api/sync/pull

Returns operations visible to the caller, strictly after `sinceVersion`.

### Query params

- `sinceVersion` (required): non-negative integer
- `boardId` (optional): UUID board scope
- `limit` (optional): 1..1000, default 500

### Response (200)

```json
{
  "items": [
    {
      "version": 43,
      "boardId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "actorUserId": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      "clientOperationId": "deviceB-204",
      "operationType": "list.created",
      "entityType": "list",
      "entityId": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "payload": {
        "title": "In Progress"
      },
      "createdAt": "2026-03-01T17:00:01.000Z"
    }
  ],
  "latestVersion": 43
}
```

## GET /api/sync/failures

Returns unresolved sync failures (dead-letter records) for the authenticated actor.

### Query params

- `boardId` (optional): UUID board scope
- `limit` (optional): 1..500, default 100

### Response (200)

```json
{
  "items": [
    {
      "id": 12,
      "actorUserId": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      "boardId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "clientOperationId": "deviceA-1001",
      "operationType": "card.updated",
      "entityType": "card",
      "entityId": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "payload": {
        "title": "Updated title",
        "expectedVersion": 1
      },
      "statusCode": 409,
      "lastErrorCode": "SyncApplyConflictError",
      "lastErrorMessage": "card version conflict",
      "attemptCount": 2,
      "firstFailedAt": "2026-03-01T17:00:00.000Z",
      "lastFailedAt": "2026-03-01T17:00:03.000Z",
      "resolvedAt": null
    }
  ]
}
```

When a later `POST /api/sync/push` succeeds with the same `clientOperationId`, the matching unresolved dead-letter record is auto-marked resolved.

## POST /api/sync/failures/:failureId/retry

Retries one unresolved dead-letter operation as the authenticated actor.

If the retry succeeds, the failure is marked resolved. If retry fails again, `attemptCount` and last error fields are updated in-place on that failure record.

### Response (201)

```json
{
  "item": {
    "status": "applied",
    "clientOperationId": "deviceA-1001",
    "version": 44,
    "boardId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "operationType": "card.updated",
    "entityType": "card",
    "entityId": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    "createdAt": "2026-03-01T17:00:04.000Z"
  },
  "latestVersion": 44
}
```

## Supported operations

- `list.created`: payload requires `title`; optional `orderIndex`
- `list.updated` or `list.moved`: payload requires `expectedVersion` and at least one of `title`, `orderIndex`
- `list.deleted`: payload requires `expectedVersion`
- `card.created`: payload requires `listId`, `title`; optional `description`, `orderIndex`
- `card.updated` or `card.moved`: payload requires `expectedVersion` and at least one of `title`, `description`, `orderIndex`, `listId`
- `card.deleted`: payload requires `expectedVersion`
- `note.created`: payload requires `title`, `content` (JSON object)
- `note.updated`: payload requires `expectedVersion`, `title`, `content` (JSON object)
- `note.deleted`: payload requires `expectedVersion`
- `board.updated`: payload requires `name`, `expectedVersion`
- `board.deleted`: payload requires `expectedVersion`

`board.created` is intentionally not allowed via sync. Use `POST /api/boards`.
Delete actions are implemented as tombstones in canonical tables (`is_deleted=true`, `deleted_at` set).
Server tracks per-board latest operation cursor in `board_sync_state` to optimize pull/catch-up latest version resolution.
Sync conflict count is exposed via `/metrics` in `counters.syncPushConflictsTotal`.
Expired tombstones can be hard-pruned via `npm run job:cleanup:tombstones` (supports `--dry-run`).

### Note content schema (v1)

For `note.created` and `note.updated`, `payload.content` must satisfy:
- object
- `type` exactly `"doc"`
- `content` must be an array

Server rejects malformed note docs with `400`.
`payload.schemaVersion` is optional; if omitted, server assumes current schema version.
If provided, it must match `GET /api/capabilities -> schemas.noteDocSchemaVersion`; mismatches are rejected with `400`.

## WebSocket board channels

### Connect

```text
ws://localhost:4000?token=<JWT>
```

Welcome event:

```json
{
  "type": "welcome",
  "message": "Connected to Syncra WebSocket server",
  "userId": "<user-uuid>",
  "reconnectHint": "resubscribe_and_catchup"
}
```

### Subscribe to board

```json
{ "type": "subscribe_board", "boardId": "<board-uuid>" }
```

### Unsubscribe from board

```json
{ "type": "unsubscribe_board", "boardId": "<board-uuid>" }
```

### Broadcast event

When `sync/push` applies an operation, subscribed board members receive:

```json
{
  "type": "sync.operation.applied",
  "data": {
    "version": 43,
    "boardId": "<board-uuid>",
    "actorUserId": "<user-uuid>",
    "clientOperationId": "deviceB-204",
    "operationType": "card.updated",
    "entityType": "card",
    "entityId": "<entity-uuid>",
    "payload": {},
    "createdAt": "2026-03-01T17:00:01.000Z"
  }
}
```

### Catch up after reconnect

Client request:

```json
{ "type": "sync_catchup", "boardId": "<board-uuid>", "sinceVersion": 0, "limit": 200 }
```

Server response:

```json
{
  "type": "sync.catchup",
  "boardId": "<board-uuid>",
  "sinceVersion": 0,
  "latestVersion": 43,
  "items": []
}
```

## Flutter reconnect guidance

Maintain `lastSeenVersion` per board in local SQLite.

On WS reconnect:
1. Reconnect with fresh JWT token.
2. Send `subscribe_board` for each locally opened/active board.
3. Send `sync_catchup` with `sinceVersion = lastSeenVersion`.
4. Apply `sync.catchup.items` in order, update `lastSeenVersion = latestVersion`.
5. Continue processing live `sync.operation.applied` events and advancing cursor.

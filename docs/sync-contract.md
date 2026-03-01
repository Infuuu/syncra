# Sync API Contract

## Auth

All sync endpoints require:

```text
Authorization: Bearer <token>
```

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

## Supported operations

- `list.created`: payload requires `title`; optional `orderIndex`
- `list.updated` or `list.moved`: payload requires `expectedVersion` and at least one of `title`, `orderIndex`
- `list.deleted`: payload requires `expectedVersion`
- `card.created`: payload requires `listId`, `title`; optional `description`, `orderIndex`
- `card.updated` or `card.moved`: payload requires `expectedVersion` and at least one of `title`, `description`, `orderIndex`, `listId`
- `card.deleted`: payload requires `expectedVersion`
- `board.updated`: payload requires `name`, `expectedVersion`
- `board.deleted`: payload requires `expectedVersion`

`board.created` is intentionally not allowed via sync. Use `POST /api/boards`.
Delete actions are implemented as tombstones in canonical tables (`is_deleted=true`, `deleted_at` set).
Server tracks per-board latest operation cursor in `board_sync_state` to optimize pull/catch-up latest version resolution.

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

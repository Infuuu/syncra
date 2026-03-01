# Syncra

Offline-first real-time Kanban collaboration starter project.

## Project Structure

- `backend/` Node.js API + WebSocket server
- `docs/` architecture and next steps

## Backend Quick Start

```bash
cd backend
cp .env.example .env
npm install
npm run db:migrate
npm run dev
```

Server runs at `http://localhost:4000`.

## Basic API Endpoints

- `GET /` service status
- `GET /health` backend + database health
- `POST /api/auth/register` create user + token
- `POST /api/auth/login` login + token
- `GET /api/boards` list boards (auth required)
- `POST /api/boards` create board `{ "name": "Demo Board" }` (auth required)
- `GET /api/boards/:boardId/me` get caller role for this board (auth required + membership)
- `GET /api/boards/:boardId/members` list board members (auth required + membership)
- `POST /api/boards/:boardId/members` add/update member by email `{ "email": "...", "role": "viewer|editor|owner" }` (owner only)
- `PATCH /api/boards/:boardId/members/:userId` update member role `{ "role": "viewer|editor|owner" }` (owner only)
- `DELETE /api/boards/:boardId/members/:userId` remove member (owner only)
- `GET /api/lists/board/:boardId` list lists by board (auth required + membership)
- `POST /api/lists` create list `{ "boardId": "...", "title": "To Do", "orderIndex": 0 }` (auth required + editor/owner)
- `GET /api/cards/list/:listId` list cards by list (auth required + membership)
- `POST /api/cards` create card (auth required + editor/owner)
- `PATCH /api/cards/:cardId` update card title/description/list/orderIndex (auth required + editor/owner)
- `POST /api/sync/push` push client operations (auth required + editor/owner on each target board)
- `GET /api/sync/pull?sinceVersion=0&boardId=<optional>&limit=<optional>` pull versioned operation log deltas for accessible boards
- Detailed sync payload contract and examples: `/Users/sharadsingh/Downloads/Resume Projects/syncra/docs/sync-contract.md`

Use header for protected routes:

```text
Authorization: Bearer <token>
```

## Tests

From backend:

```bash
npm test
```

This runs migrations first, then executes RBAC integration tests.

## WebSocket

Connect with JWT token in query string:

```text
ws://localhost:4000?token=<JWT>
```

On connect, server sends `welcome`.

Client can subscribe to board channels:

```json
{ "type": "subscribe_board", "boardId": "<board-uuid>" }
```

Unsubscribe:

```json
{ "type": "unsubscribe_board", "boardId": "<board-uuid>" }
```

Catch up missed operations after reconnect:

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

Server `welcome` includes:

```json
{ "type": "welcome", "reconnectHint": "resubscribe_and_catchup" }
```

For Flutter recovery after disconnect:
1. Reconnect with JWT token.
2. Re-subscribe all active board channels.
3. For each board, send `sync_catchup` using last persisted `sinceVersion`.
4. Apply returned operations to local SQLite and persist new cursor.

When sync operations are applied for a subscribed board, server broadcasts:

```json
{
  "type": "sync.operation.applied",
  "data": {
    "version": 42,
    "boardId": "<board-uuid>",
    "operationType": "card.updated",
    "entityType": "card",
    "entityId": "<entity-uuid>"
  }
}
```

## Notes

- CRUD now uses PostgreSQL tables through a repository layer.
- Run `npm run db:migrate` whenever you need to initialize a fresh database.
- If PostgreSQL is not running, endpoints will fail because DB is required.
- New tables: `users`, `board_members` (plus `boards`, `lists`, `cards`).
- Role model: `viewer` (read), `editor` (read/write cards+lists), `owner` (full access + member management).
- Sync operations are stored server-side with monotonic `version` for delta pulls.
- `sync/push` now applies supported operations to canonical tables in the same DB transaction as operation-log insert.
- `sync/push` is atomic per request batch: if any operation fails, the full batch is rolled back.
Supported operation actions: `created`, `updated`, `moved`, `deleted` for `list` and `card`; `updated`, `deleted` for `board`.
- `board.created` is intentionally rejected via sync; create boards with `POST /api/boards` so owner membership is created correctly.
- Optimistic concurrency is enforced for update/move/delete sync actions using `payload.expectedVersion`.
- On version conflict, `sync/push` returns `409` with the latest server snapshot in:
  - `conflict.serverSnapshot`
- Rate limiting is enabled:
  - `/api/auth`: fixed-window IP limit
  - `/api/sync`: fixed-window user/IP limit
- Request size guards are enabled:
  - global JSON parser size limit (`JSON_BODY_LIMIT`)
  - additional sync payload byte cap (`SYNC_BODY_MAX_BYTES`)

## Next Steps

- Add operation log endpoints for offline sync

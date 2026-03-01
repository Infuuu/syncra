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

Docker quick start:

```bash
docker compose up --build
```

This starts:
- PostgreSQL on `localhost:5432`
- Backend on `localhost:4000` (runs migrations on container startup)

## Basic API Endpoints

- `GET /` service status
- `GET /health/live` liveness probe
- `GET /health/ready` readiness probe (includes DB check)
- `GET /health` compatibility health endpoint (includes DB check)
- `GET /openapi.json` OpenAPI 3.0 API contract
- `GET /docs` Swagger UI for interactive API exploration
- `GET /metrics` backend uptime + in-memory counters
- `GET /metrics/prometheus` Prometheus text exposition format
- `POST /api/auth/register` create user + access/refresh token pair
- `POST /api/auth/login` login + access/refresh token pair
- `POST /api/auth/refresh` rotate refresh token and issue a new access/refresh pair
- `POST /api/auth/logout` revoke refresh token
- `GET /api/boards` list boards (auth required)
- `POST /api/boards` create board `{ "name": "Demo Board" }` (auth required)
- `GET /api/boards/:boardId/audit?limit=<optional>` list board audit events (auth required + membership)
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
- `GET /api/sync/failures?boardId=<optional>&limit=<optional>` list unresolved sync failures for current user
- `POST /api/sync/failures/:failureId/retry` retry a dead-letter sync operation by id (auth required + editor/owner on target board)
- Detailed sync payload contract and examples: `/Users/sharadsingh/Downloads/Resume Projects/syncra/docs/sync-contract.md`

Use header for protected routes:

```text
Authorization: Bearer <token>
```

Every response includes:

```text
x-request-id: <uuid>
```

API docs:
- OpenAPI JSON: `http://localhost:4000/openapi.json`
- Swagger UI: `http://localhost:4000/docs`

## Tests

From backend:

```bash
npm test
```

This runs migrations first, then executes RBAC integration tests.

Tombstone cleanup job:

```bash
npm run job:cleanup:tombstones
```

Dry run:

```bash
npm run job:cleanup:tombstones -- --dry-run
```

Maintenance cleanup job (refresh tokens + resolved sync failures + audit logs):

```bash
npm run job:cleanup:maintenance
```

Dry run:

```bash
npm run job:cleanup:maintenance -- --dry-run
```

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
- Auth now uses short-lived access tokens plus rotating refresh tokens persisted server-side; logout revokes refresh tokens.
- Security-sensitive actions are audited in `audit_logs` (auth refresh/logout/reuse, board creation/deletion, member role changes).
- Request validation is centralized in a shared schema module and applied across auth, sync, board, member, list, and card write/query surfaces.
- Sync operations are stored server-side with monotonic `version` for delta pulls.
- `sync/push` now applies supported operations to canonical tables in the same DB transaction as operation-log insert.
- `sync/push` is atomic per request batch: if any operation fails, the full batch is rolled back.
Supported operation actions: `created`, `updated`, `moved`, `deleted` for `list` and `card`; `updated`, `deleted` for `board`.
- `board.created` is intentionally rejected via sync; create boards with `POST /api/boards` so owner membership is created correctly.
- Failed sync operations are tracked in dead-letter storage with `attemptCount` and can be resolved automatically when retry succeeds with same `clientOperationId`.
- Dead-letter failures can also be replayed server-side with `POST /api/sync/failures/:failureId/retry`.
- Optimistic concurrency is enforced for update/move/delete sync actions using `payload.expectedVersion`.
- On version conflict, `sync/push` returns `409` with the latest server snapshot in:
  - `conflict.serverSnapshot`
- Deletes are tombstoned (`is_deleted`, `deleted_at`) in canonical tables for safer offline reconciliation.
- Tombstones are retained for `TOMBSTONE_RETENTION_DAYS` and can be pruned by cleanup job.
- Per-board sync cursor state is maintained in `board_sync_state` to speed up latest-version calculations for pull/catch-up.
- Rate limiting is enabled:
  - `/api/auth`: fixed-window IP limit
  - `/api/sync`: fixed-window user/IP limit
- Request size guards are enabled:
  - global JSON parser size limit (`JSON_BODY_LIMIT`)
  - additional sync payload byte cap (`SYNC_BODY_MAX_BYTES`)
- Notes module controls:
  - capability endpoint: `GET /api/capabilities` (client-safe feature/limit discovery)
  - feature flag: `NOTES_ENABLED`
  - note doc schema version: `NOTE_DOC_SCHEMA_VERSION` (surfaced via capabilities)
  - note content payload cap: `NOTE_CONTENT_MAX_BYTES`
  - capability endpoint also returns a stable `errorCodes` map for client-side branching
  - board notes listing supports offset pagination or cursor pagination (`cursor` + `nextCursor`)
  - note sync payload schema enforces `payload.content.type === "doc"` and array `payload.content.content`
  - optional `payload.schemaVersion` on `note.created`/`note.updated` must match capabilities schema version
  - sync validation/conflict errors return machine-readable `errorCode` alongside `error`
- Structured JSON logs are emitted for each request with requestId, method, path, statusCode, durationMs, userId, and ip.
- `syncPushConflictsTotal` metric is tracked and exposed via `/metrics`.
- Metrics now include route-labeled request counters, route-labeled request-duration histograms, sync push error counters by reason/status, and note sync apply counters (including board-labeled note apply metrics).
- Docker runtime is provided via `/Users/sharadsingh/Downloads/Resume Projects/syncra/docker-compose.yml` and `/Users/sharadsingh/Downloads/Resume Projects/syncra/backend/Dockerfile`.
- Maintenance cleanup retention knobs:
  - `REFRESH_TOKEN_CLEANUP_RETENTION_DAYS`
  - `SYNC_FAILURE_RETENTION_DAYS`
  - `AUDIT_LOG_RETENTION_DAYS`

## Next Steps

- Add operation log endpoints for offline sync

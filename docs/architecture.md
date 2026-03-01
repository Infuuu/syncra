# Syncra Architecture (Basic)

## Current Scope

- Backend starter with Express + WebSocket
- PostgreSQL connection check endpoint (`/health`)
- Placeholder REST endpoint (`/api/boards`)

## Planned Next Milestones

1. Add database schema and migrations:
   - users
   - boards
   - lists
   - cards
   - operations (sync queue)
2. Add JWT authentication
3. Add board/list/card CRUD APIs
4. Add WebSocket event types for collaboration
5. Scaffold Flutter app with local SQLite
6. Implement offline sync engine

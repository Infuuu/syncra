const { WebSocketServer } = require('ws');
const { verifyAccessToken } = require('../services/tokenService');
const boardMemberRepository = require('../repositories/boardMemberRepository');
const syncRepository = require('../repositories/syncRepository');

const setupWebSocket = (server) => {
  const wss = new WebSocketServer({ server });
  const HEARTBEAT_INTERVAL_MS = 30000;

  const send = (socket, event) => {
    if (socket.readyState !== 1) return;
    socket.send(JSON.stringify(event));
  };

  const parseSinceVersion = (value) => {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 0) return null;
    return parsed;
  };

  const parseTokenFromRequest = (request) => {
    const url = new URL(request.url || '/', 'http://localhost');
    return url.searchParams.get('token');
  };

  const broadcastSyncOperation = (operation) => {
    const boardId = String(operation?.boardId || '');
    if (!boardId) return;

    for (const socket of wss.clients) {
      if (socket.readyState !== 1) continue;
      if (!socket.auth?.userId) continue;
      if (!socket.subscriptions?.has(boardId)) continue;

      send(socket, {
        type: 'sync.operation.applied',
        data: operation
      });
    }
  };

  wss.on('connection', (socket, request) => {
    const token = parseTokenFromRequest(request);
    if (!token) {
      socket.close(1008, 'missing_token');
      return;
    }

    try {
      const payload = verifyAccessToken(token);
      socket.auth = {
        userId: payload.sub,
        email: payload.email
      };
      socket.subscriptions = new Set();
      socket.isAlive = true;
    } catch (_error) {
      socket.close(1008, 'invalid_token');
      return;
    }

    send(socket, {
      type: 'welcome',
      message: 'Connected to Syncra WebSocket server',
      userId: socket.auth.userId,
      reconnectHint: 'resubscribe_and_catchup'
    });

    socket.on('pong', () => {
      socket.isAlive = true;
    });

    socket.on('message', async (raw) => {
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch (_error) {
        send(socket, { type: 'error', error: 'invalid_json_message' });
        return;
      }

      const type = String(message?.type || '').trim();
      const boardId = String(message?.boardId || '').trim();

      if (type === 'subscribe_board') {
        if (!boardId) {
          send(socket, { type: 'error', error: 'boardId is required' });
          return;
        }

        const role = await boardMemberRepository.getBoardRole({
          boardId,
          userId: socket.auth.userId
        });

        if (!role) {
          send(socket, { type: 'error', error: 'forbidden_board_subscription', boardId });
          return;
        }

        socket.subscriptions.add(boardId);
        send(socket, { type: 'subscribed_board', boardId, role });
        return;
      }

      if (type === 'unsubscribe_board') {
        if (!boardId) {
          send(socket, { type: 'error', error: 'boardId is required' });
          return;
        }

        socket.subscriptions.delete(boardId);
        send(socket, { type: 'unsubscribed_board', boardId });
        return;
      }

      if (type === 'ping') {
        send(socket, { type: 'pong', at: new Date().toISOString() });
        return;
      }

      if (type === 'sync_catchup') {
        if (!boardId) {
          send(socket, { type: 'error', error: 'boardId is required' });
          return;
        }

        const sinceVersion = parseSinceVersion(message?.sinceVersion ?? 0);
        if (sinceVersion === null) {
          send(socket, { type: 'error', error: 'sinceVersion must be a non-negative integer' });
          return;
        }

        const limitRaw = Number(message?.limit ?? 200);
        const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 1000) : 200;

        const role = await boardMemberRepository.getBoardRole({
          boardId,
          userId: socket.auth.userId
        });

        if (!role) {
          send(socket, { type: 'error', error: 'forbidden_board_subscription', boardId });
          return;
        }

        const items = await syncRepository.listOperationsForUserSinceVersion({
          userId: socket.auth.userId,
          sinceVersion,
          boardId,
          limit
        });

        const latestVersion = await syncRepository.getLatestVisibleVersionForUser({
          userId: socket.auth.userId,
          sinceVersion,
          boardId
        });

        send(socket, {
          type: 'sync.catchup',
          boardId,
          sinceVersion,
          latestVersion,
          items
        });
        return;
      }

      send(socket, { type: 'error', error: `unsupported_message_type: ${type}` });
    });

    socket.on('close', () => {
      if (socket.subscriptions) {
        socket.subscriptions.clear();
      }
    });
  });

  const heartbeatInterval = setInterval(() => {
    for (const socket of wss.clients) {
      if (socket.readyState !== 1) continue;

      if (socket.isAlive === false) {
        socket.terminate();
        continue;
      }

      socket.isAlive = false;
      socket.ping();
    }
  }, HEARTBEAT_INTERVAL_MS);
  heartbeatInterval.unref();

  wss.on('close', () => {
    clearInterval(heartbeatInterval);
  });

  return { wss, broadcastSyncOperation };
};

module.exports = {
  setupWebSocket
};

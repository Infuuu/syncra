const { WebSocketServer } = require('ws');
const { verifyAuthToken } = require('../services/tokenService');
const boardMemberRepository = require('../repositories/boardMemberRepository');

const setupWebSocket = (server) => {
  const wss = new WebSocketServer({ server });

  const send = (socket, event) => {
    if (socket.readyState !== 1) return;
    socket.send(JSON.stringify(event));
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
      const payload = verifyAuthToken(token);
      socket.auth = {
        userId: payload.sub,
        email: payload.email
      };
      socket.subscriptions = new Set();
    } catch (_error) {
      socket.close(1008, 'invalid_token');
      return;
    }

    send(socket, {
      type: 'welcome',
      message: 'Connected to Syncra WebSocket server',
      userId: socket.auth.userId
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

      send(socket, { type: 'error', error: `unsupported_message_type: ${type}` });
    });
  });

  return { wss, broadcastSyncOperation };
};

module.exports = {
  setupWebSocket
};

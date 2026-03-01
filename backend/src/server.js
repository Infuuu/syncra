const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { setupWebSocket } = require('./realtime/ws');

const server = http.createServer(app);
const { broadcastSyncOperation } = setupWebSocket(server);
app.locals.broadcastSyncOperation = broadcastSyncOperation;

server.listen(env.port, () => {
  console.log(`Syncra backend listening on http://localhost:${env.port}`);
});

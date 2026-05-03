const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { setupWebSocket } = require('./realtime/ws');

const { run: runMigrations } = require('./db/migrate');

const server = http.createServer(app);
const { broadcastSyncOperation } = setupWebSocket(server);
app.locals.broadcastSyncOperation = broadcastSyncOperation;

async function startServer() {
  try {
    // Run migrations before starting the server
    await runMigrations();
    
    server.listen(env.port, () => {
      console.log(`Syncra backend listening on port ${env.port}`);
    });
  } catch (error) {
    console.error('Failed to start server due to migration error:', error);
    process.exit(1);
  }
}

startServer();

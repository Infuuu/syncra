const express = require('express');
const cors = require('cors');

const healthRoutes = require('./routes/healthRoutes');
const authRoutes = require('./routes/authRoutes');
const boardRoutes = require('./routes/boardRoutes');
const boardMemberRoutes = require('./routes/boardMemberRoutes');
const listRoutes = require('./routes/listRoutes');
const cardRoutes = require('./routes/cardRoutes');
const syncRoutes = require('./routes/syncRoutes');
const { requireAuth } = require('./middleware/authMiddleware');

const app = express();
app.locals.broadcastSyncOperation = () => {};

app.use(cors());
app.use(express.json());

app.get('/', (_req, res) => {
  res.json({
    service: 'syncra-backend',
    status: 'running'
  });
});

app.use('/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/boards', requireAuth, boardRoutes);
app.use('/api/boards/:boardId/members', requireAuth, boardMemberRoutes);
app.use('/api/lists', requireAuth, listRoutes);
app.use('/api/cards', requireAuth, cardRoutes);
app.use('/api/sync', requireAuth, syncRoutes);

app.use((req, res) => {
  res.status(404).json({ error: `route not found: ${req.method} ${req.path}` });
});

module.exports = app;

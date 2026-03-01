const express = require('express');
const { checkDbHealth } = require('../db/pool');

const router = express.Router();

router.get('/live', (_req, res) => {
  res.status(200).json({ ok: true, service: 'up' });
});

router.get('/ready', async (_req, res) => {
  const status = await checkDbHealth();
  const code = status.ok ? 200 : 500;
  res.status(code).json(status);
});

router.get('/', async (_req, res) => {
  const status = await checkDbHealth();
  const code = status.ok ? 200 : 500;
  res.status(code).json({
    ...status,
    live: true
  });
});

module.exports = router;

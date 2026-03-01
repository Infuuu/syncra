const express = require('express');
const { checkDbHealth } = require('../db/pool');

const router = express.Router();

router.get('/', async (_req, res) => {
  const status = await checkDbHealth();
  const code = status.ok ? 200 : 500;
  res.status(code).json(status);
});

module.exports = router;

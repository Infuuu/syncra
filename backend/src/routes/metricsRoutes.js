const express = require('express');
const metricsService = require('../services/metricsService');

const router = express.Router();

router.get('/', (_req, res) => {
  res.json({
    uptimeSeconds: Number(process.uptime().toFixed(3)),
    counters: metricsService.getSnapshot()
  });
});

module.exports = router;

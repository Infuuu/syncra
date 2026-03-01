const express = require('express');
const bcrypt = require('bcryptjs');

const userRepository = require('../repositories/userRepository');
const { signAuthToken } = require('../services/tokenService');
const { badRequest, conflict, unauthorized, serverError } = require('../utils/http');

const router = express.Router();

router.post('/register', async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  const displayName = String(req.body?.displayName || '').trim();

  if (!email) return badRequest(res, 'email is required');
  if (!password) return badRequest(res, 'password is required');
  if (!displayName) return badRequest(res, 'displayName is required');
  if (password.length < 8) return badRequest(res, 'password must be at least 8 characters');

  try {
    const existing = await userRepository.getUserByEmail(email);
    if (existing) return conflict(res, 'email already registered');

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await userRepository.createUser({ email, passwordHash, displayName });
    const token = signAuthToken(user);

    return res.status(201).json({ user, token });
  } catch (error) {
    return serverError(res, error.message);
  }
});

router.post('/login', async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');

  if (!email) return badRequest(res, 'email is required');
  if (!password) return badRequest(res, 'password is required');

  try {
    const user = await userRepository.getUserByEmail(email);
    if (!user) return unauthorized(res, 'invalid email or password');

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) return unauthorized(res, 'invalid email or password');

    const token = signAuthToken(user);

    return res.json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      },
      token
    });
  } catch (error) {
    return serverError(res, error.message);
  }
});

module.exports = router;

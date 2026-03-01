const jwt = require('jsonwebtoken');
const env = require('../config/env');

const signAuthToken = (user) =>
  jwt.sign(
    {
      sub: user.id,
      email: user.email
    },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );

const verifyAuthToken = (token) => jwt.verify(token, env.jwtSecret);

module.exports = {
  signAuthToken,
  verifyAuthToken
};

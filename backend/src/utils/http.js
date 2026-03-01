const badRequest = (res, message) => res.status(400).json({ error: message });
const unauthorized = (res, message = 'unauthorized') => res.status(401).json({ error: message });
const forbidden = (res, message = 'forbidden') => res.status(403).json({ error: message });
const notFound = (res, message) => res.status(404).json({ error: message });
const conflict = (res, message) => res.status(409).json({ error: message });
const serverError = (res, message = 'internal_server_error') =>
  res.status(500).json({ error: message });

module.exports = {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  serverError
};

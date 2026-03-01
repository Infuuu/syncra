const limitRequestBodyBytes = (maxBytes) => (req, res, next) => {
  const contentLengthHeader = req.headers['content-length'];
  const contentLength = contentLengthHeader ? Number(contentLengthHeader) : null;

  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    return res.status(413).json({ error: 'payload_too_large' });
  }

  if (req.body && typeof req.body === 'object') {
    const size = Buffer.byteLength(JSON.stringify(req.body), 'utf8');
    if (size > maxBytes) {
      return res.status(413).json({ error: 'payload_too_large' });
    }
  }

  return next();
};

module.exports = {
  limitRequestBodyBytes
};

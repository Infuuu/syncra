const counters = {
  httpRequestsTotal: 0,
  http2xxTotal: 0,
  http4xxTotal: 0,
  http5xxTotal: 0,
  rateLimitExceededTotal: 0,
  syncPushConflictsTotal: 0
};

const incrementCounter = (key, by = 1) => {
  if (!Object.prototype.hasOwnProperty.call(counters, key)) return;
  counters[key] += by;
};

const observeHttpResponse = (statusCode) => {
  incrementCounter('httpRequestsTotal', 1);
  if (statusCode >= 200 && statusCode < 300) incrementCounter('http2xxTotal', 1);
  else if (statusCode >= 400 && statusCode < 500) incrementCounter('http4xxTotal', 1);
  else if (statusCode >= 500) incrementCounter('http5xxTotal', 1);
};

const getSnapshot = () => ({
  ...counters
});

module.exports = {
  incrementCounter,
  observeHttpResponse,
  getSnapshot
};

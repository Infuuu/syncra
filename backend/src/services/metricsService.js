const counters = {
  httpRequestsTotal: 0,
  http2xxTotal: 0,
  http4xxTotal: 0,
  http5xxTotal: 0,
  rateLimitExceededTotal: 0,
  syncPushConflictsTotal: 0,
  syncNoteConflictTotal: 0,
  syncNoteValidationFailTotal: 0
};

const labeledCounters = {
  httpRequestsByRouteTotal: new Map(),
  syncPushErrorsTotal: new Map(),
  syncNoteApplyTotal: new Map(),
  syncNoteApplyByBoardTotal: new Map()
};

const REQUEST_DURATION_BUCKETS_MS = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
const requestDurationByRoute = new Map();

const incrementCounter = (key, by = 1) => {
  if (!Object.prototype.hasOwnProperty.call(counters, key)) return;
  counters[key] += by;
};

const normalizeLabels = (labels) =>
  Object.keys(labels || {})
    .sort()
    .map((key) => [key, String(labels[key])]);

const labelsToKey = (labels) =>
  normalizeLabels(labels)
    .map(([k, v]) => `${k}=${v}`)
    .join('|');

const keyToLabels = (key) => {
  if (!key) return {};
  return key.split('|').reduce((acc, pair) => {
    const [k, ...rest] = pair.split('=');
    acc[k] = rest.join('=');
    return acc;
  }, {});
};

const incrementLabeledCounter = (name, labels = {}, by = 1) => {
  const target = labeledCounters[name];
  if (!target) return;
  const key = labelsToKey(labels);
  target.set(key, (target.get(key) || 0) + by);
};

const normalizeRoutePath = (path) => {
  const value = String(path || '').trim();
  if (!value) return 'unknown';
  return value.replace(/[0-9a-fA-F-]{8,}/g, ':id');
};

const ensureDurationSeries = (labelsKey) => {
  let series = requestDurationByRoute.get(labelsKey);
  if (!series) {
    series = {
      buckets: REQUEST_DURATION_BUCKETS_MS.map(() => 0),
      count: 0,
      sumMs: 0
    };
    requestDurationByRoute.set(labelsKey, series);
  }
  return series;
};

const observeHttpResponse = (statusCode) => {
  incrementCounter('httpRequestsTotal', 1);
  if (statusCode >= 200 && statusCode < 300) incrementCounter('http2xxTotal', 1);
  else if (statusCode >= 400 && statusCode < 500) incrementCounter('http4xxTotal', 1);
  else if (statusCode >= 500) incrementCounter('http5xxTotal', 1);
};

const observeHttpRequest = ({ method, routePath, statusCode, durationMs }) => {
  observeHttpResponse(statusCode);

  const statusFamily = `${Math.floor(Number(statusCode || 0) / 100)}xx`;
  const labels = {
    method: String(method || 'UNKNOWN').toUpperCase(),
    route: normalizeRoutePath(routePath),
    status_family: statusFamily
  };

  incrementLabeledCounter('httpRequestsByRouteTotal', labels, 1);

  const key = labelsToKey(labels);
  const series = ensureDurationSeries(key);
  series.count += 1;
  series.sumMs += Number(durationMs || 0);
  const observed = Number(durationMs || 0);
  REQUEST_DURATION_BUCKETS_MS.forEach((upper, idx) => {
    if (observed <= upper) {
      series.buckets[idx] += 1;
    }
  });
};

const getSnapshot = () => ({
  ...counters
});

const getLabeledCounterSnapshot = () => {
  const output = {};
  for (const [name, entries] of Object.entries(labeledCounters)) {
    output[name] = Array.from(entries.entries()).map(([key, value]) => ({
      labels: keyToLabels(key),
      value
    }));
  }
  return output;
};

const getRequestDurationSnapshot = () =>
  Array.from(requestDurationByRoute.entries()).map(([key, series]) => ({
    labels: keyToLabels(key),
    buckets: REQUEST_DURATION_BUCKETS_MS.map((upperBound, idx) => ({
      le: upperBound,
      value: series.buckets[idx]
    })),
    count: series.count,
    sumMs: Number(series.sumMs.toFixed(3))
  }));

module.exports = {
  incrementCounter,
  incrementLabeledCounter,
  observeHttpResponse,
  observeHttpRequest,
  getSnapshot,
  getLabeledCounterSnapshot,
  getRequestDurationSnapshot,
  REQUEST_DURATION_BUCKETS_MS
};

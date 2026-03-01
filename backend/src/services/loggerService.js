const log = (level, event, fields = {}) => {
  const payload = {
    timestamp: new Date().toISOString(),
    level,
    event,
    ...fields
  };

  const line = JSON.stringify(payload);
  if (level === 'error') {
    console.error(line);
    return;
  }
  console.log(line);
};

const info = (event, fields) => log('info', event, fields);
const error = (event, fields) => log('error', event, fields);

module.exports = {
  info,
  error
};

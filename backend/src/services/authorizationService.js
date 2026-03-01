const ROLE_ORDER = {
  viewer: 1,
  editor: 2,
  owner: 3
};

const hasRequiredRole = (actualRole, minimumRole) => {
  const actual = ROLE_ORDER[actualRole] || 0;
  const required = ROLE_ORDER[minimumRole] || 0;
  return actual >= required;
};

module.exports = {
  ROLE_ORDER,
  hasRequiredRole
};

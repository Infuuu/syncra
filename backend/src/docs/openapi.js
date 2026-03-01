const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'Syncra Backend API',
    version: '0.1.0',
    description: 'Offline-first real-time Kanban collaboration backend.'
  },
  servers: [
    {
      url: 'http://localhost:4000'
    }
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT'
      }
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          error: { type: 'string' }
        },
        required: ['error']
      }
    }
  },
  paths: {
    '/': {
      get: {
        summary: 'Service status',
        responses: {
          200: { description: 'OK' }
        }
      }
    },
    '/health/live': {
      get: {
        summary: 'Liveness probe',
        responses: {
          200: { description: 'Alive' }
        }
      }
    },
    '/health/ready': {
      get: {
        summary: 'Readiness probe',
        responses: {
          200: { description: 'Ready' },
          500: { description: 'Not ready' }
        }
      }
    },
    '/metrics': {
      get: {
        summary: 'Metrics JSON',
        responses: {
          200: { description: 'Metrics snapshot' }
        }
      }
    },
    '/metrics/prometheus': {
      get: {
        summary: 'Metrics Prometheus format',
        responses: {
          200: { description: 'Prometheus exposition text' }
        }
      }
    },
    '/api/auth/register': {
      post: {
        summary: 'Register user',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password', 'displayName'],
                properties: {
                  email: { type: 'string', format: 'email' },
                  password: { type: 'string', minLength: 8 },
                  displayName: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          201: { description: 'Registered' },
          400: { description: 'Validation error' },
          409: { description: 'Email already exists' }
        }
      }
    },
    '/api/auth/login': {
      post: {
        summary: 'Login user',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                  email: { type: 'string', format: 'email' },
                  password: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          200: { description: 'Logged in' },
          401: { description: 'Invalid credentials' }
        }
      }
    },
    '/api/auth/refresh': {
      post: {
        summary: 'Refresh access token',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['refreshToken'],
                properties: {
                  refreshToken: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          200: { description: 'Token rotated' },
          401: { description: 'Refresh invalid or reused' }
        }
      }
    },
    '/api/auth/logout': {
      post: {
        summary: 'Logout session',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['refreshToken'],
                properties: {
                  refreshToken: { type: 'string' }
                }
              }
            }
          }
        },
        responses: {
          204: { description: 'Logged out' }
        }
      }
    },
    '/api/boards': {
      get: {
        summary: 'List boards',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Board list' }, 401: { description: 'Unauthorized' } }
      },
      post: {
        summary: 'Create board',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['name'],
                properties: {
                  name: { type: 'string' }
                }
              }
            }
          }
        },
        responses: { 201: { description: 'Created' }, 401: { description: 'Unauthorized' } }
      }
    },
    '/api/sync/push': {
      post: {
        summary: 'Push sync operations',
        security: [{ bearerAuth: [] }],
        responses: {
          201: { description: 'Applied' },
          400: { description: 'Validation error' },
          403: { description: 'Forbidden' },
          409: { description: 'Conflict' }
        }
      }
    },
    '/api/sync/pull': {
      get: {
        summary: 'Pull sync operations',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'sinceVersion', schema: { type: 'integer', minimum: 0 } },
          { in: 'query', name: 'boardId', schema: { type: 'string' } },
          { in: 'query', name: 'limit', schema: { type: 'integer', minimum: 1 } }
        ],
        responses: { 200: { description: 'Pulled' } }
      }
    },
    '/api/sync/failures': {
      get: {
        summary: 'List unresolved sync failures',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Failure list' } }
      }
    },
    '/api/sync/failures/{failureId}/retry': {
      post: {
        summary: 'Retry one failed sync operation',
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: 'path',
            name: 'failureId',
            required: true,
            schema: { type: 'integer', minimum: 1 }
          }
        ],
        responses: { 201: { description: 'Retried' }, 404: { description: 'Not found' } }
      }
    }
  }
};

module.exports = {
  openApiSpec
};

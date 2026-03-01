const express = require('express');
const env = require('../config/env');

const router = express.Router();

router.get('/', (_req, res) => {
  res.json({
    features: {
      notesEnabled: env.notesEnabled
    },
    schemas: {
      noteDocSchemaVersion: env.noteDocSchemaVersion
    },
    errorCodes: {
      sync: {
        versionConflict: 'version_conflict'
      },
      notes: {
        featureDisabled: 'notes_feature_disabled',
        schemaVersionInvalid: 'note_schema_version_invalid',
        schemaVersionUnsupported: 'note_schema_version_unsupported',
        contentInvalid: 'note_content_invalid'
      }
    },
    limits: {
      noteContentMaxBytes: env.noteContentMaxBytes,
      syncBodyMaxBytes: env.syncBodyMaxBytes
    }
  });
});

module.exports = router;

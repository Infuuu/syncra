const express = require('express');
const { requireAuth } = require('../middleware/authMiddleware');
const noteRepository = require('../repositories/noteRepository');

const router = express.Router();

router.use(requireAuth);

// GET /api/notes - List all global notes
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit, 10) || 100;
    const offset = parseInt(req.query.offset, 10) || 0;
    
    const notes = await noteRepository.listGlobalNotes({
      userId: req.user.id,
      limit,
      offset
    });
    
    res.json({ items: notes });
  } catch (err) {
    console.error('Error fetching global notes:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/notes - Create a global note
router.post('/', async (req, res) => {
  try {
    const { id, title, content } = req.body;
    
    if (!id) {
      return res.status(400).json({ error: 'Note ID is required' });
    }
    
    const newNote = await noteRepository.createNote({
      noteInput: {
        id,
        boardId: null,
        createdBy: req.user.id,
        title: title || '',
        content: content || {}
      }
    });
    
    res.status(201).json(newNote);
  } catch (err) {
    console.error('Error creating global note:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/notes/:id - Update a global note
router.patch('/:id', async (req, res) => {
  try {
    const { title, content, isDeleted } = req.body;
    
    const patch = {};
    if (title !== undefined) patch.title = title;
    if (content !== undefined) patch.content = content;
    if (isDeleted !== undefined) patch.isDeleted = isDeleted;
    
    if (Object.keys(patch).length === 0) {
      return res.status(400).json({ error: 'No updates provided' });
    }
    
    const updatedNote = await noteRepository.updateGlobalNote({
      noteId: req.params.id,
      userId: req.user.id,
      patch
    });
    
    if (!updatedNote) {
      return res.status(404).json({ error: 'Note not found or unauthorized' });
    }
    
    res.json(updatedNote);
  } catch (err) {
    console.error('Error updating global note:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/notes/:id - Soft delete a global note
router.delete('/:id', async (req, res) => {
  try {
    const updatedNote = await noteRepository.updateGlobalNote({
      noteId: req.params.id,
      userId: req.user.id,
      patch: { isDeleted: true }
    });
    
    if (!updatedNote) {
      return res.status(404).json({ error: 'Note not found or unauthorized' });
    }
    
    res.json({ message: 'Note deleted' });
  } catch (err) {
    console.error('Error deleting global note:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

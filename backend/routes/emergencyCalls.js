const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

const EMERGENCY_CALLS_NODE = 'emergencyCalls';

// Get all emergency calls
router.get('/', async (req, res) => {
  try {
    const snapshot = await db.ref(EMERGENCY_CALLS_NODE).once('value');
    const calls = snapshot.val() || {};
    res.json(calls);
  } catch (error) {
    console.error('Error fetching emergency calls:', error);
    res.status(500).json({ error: 'Failed to fetch emergency calls' });
  }
});

// Get emergency call statistics
router.get('/stats', async (req, res) => {
  try {
    // Align with frontend data source used by EmergencyCalls.jsx
    const root = await db.ref('StationsCallLogs').once('value');
    const data = root.val() || {};

    const active = data.ActiveCalls || {};
    const answeredNode = data.AnsweredCalls || {};
    const missedNode = data.MissedCalls || {};

    // Recursively count leaf call objects. A "call-like" object is one that
    // looks like a record (has any of: id, status, time/timestamp/dateTime)
    const isCallLike = (val) => {
      if (!val || typeof val !== 'object') return false;
      const keys = Object.keys(val);
      const markers = ['id', 'status', 'time', 'timestamp', 'dateTime', 'caller'];
      return keys.some(k => markers.includes(k));
    };

    const countCalls = (node) => {
      if (!node || typeof node !== 'object') return 0;
      let count = 0;
      for (const key of Object.keys(node)) {
        const val = node[key];
        if (isCallLike(val)) {
          count += 1;
        } else if (val && typeof val === 'object') {
          count += countCalls(val);
        }
      }
      return count;
    };

    const ongoing = countCalls(active);
    const answered = countCalls(answeredNode);
    const missed = countCalls(missedNode);

    const stats = {
      total: ongoing + answered + missed, // total number of all calls
      ongoing,
      answered,
      missed,
    };

    res.json(stats);
  } catch (error) {
    console.error('Error fetching emergency call stats:', error);
    res.status(500).json({ error: 'Failed to fetch emergency call statistics' });
  }
});

// Get a specific emergency call
router.get('/:id', async (req, res) => {
  try {
    const snapshot = await db.ref(`${EMERGENCY_CALLS_NODE}/${req.params.id}`).once('value');
    const call = snapshot.val();
    
    if (!call) {
      return res.status(404).json({ error: 'Emergency call not found' });
    }
    
    res.json(call);
  } catch (error) {
    console.error('Error fetching emergency call:', error);
    res.status(500).json({ error: 'Failed to fetch emergency call' });
  }
});

// Create a new emergency call
router.post('/', async (req, res) => {
  try {
    const callData = req.body;
    const callId = callData.id || `CALL_${Date.now()}`;
    const timestamp = Date.now();
    
    const emergencyCall = {
      ...callData,
      id: callId,
      createdAt: timestamp,
      updatedAt: timestamp,
      status: callData.status || 'Ongoing'
    };
    
    await db.ref(`${EMERGENCY_CALLS_NODE}/${callId}`).set(emergencyCall);
    res.status(201).json({ message: 'Emergency call created', id: callId });
  } catch (error) {
    console.error('Error creating emergency call:', error);
    res.status(500).json({ error: 'Failed to create emergency call' });
  }
});

// Update an emergency call
router.put('/:id', async (req, res) => {
  try {
    const callId = req.params.id;
    const updates = {
      ...req.body,
      updatedAt: Date.now()
    };
    
    const snapshot = await db.ref(`${EMERGENCY_CALLS_NODE}/${callId}`).once('value');
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Emergency call not found' });
    }
    
    await db.ref(`${EMERGENCY_CALLS_NODE}/${callId}`).update(updates);
    res.json({ message: 'Emergency call updated' });
  } catch (error) {
    console.error('Error updating emergency call:', error);
    res.status(500).json({ error: 'Failed to update emergency call' });
  }
});

// Delete an emergency call
router.delete('/:id', async (req, res) => {
  try {
    const callId = req.params.id;
    
    const snapshot = await db.ref(`${EMERGENCY_CALLS_NODE}/${callId}`).once('value');
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Emergency call not found' });
    }
    
    await db.ref(`${EMERGENCY_CALLS_NODE}/${callId}`).remove();
    res.json({ message: 'Emergency call deleted' });
  } catch (error) {
    console.error('Error deleting emergency call:', error);
    res.status(500).json({ error: 'Failed to delete emergency call' });
  }
});

module.exports = router;

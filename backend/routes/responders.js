const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// Get all Responder stations
router.get('/', async (req, res) => {
  try {
    const snapshot = await db.ref('Responders').once('value');
    const stations = snapshot.val() || {};
    res.json(Object.keys(stations));
  } catch (error) {
    console.error('Error fetching Responder stations:', error);
    res.status(500).json({ error: 'Failed to fetch responder stations' });
  }
});

// Get all responders for a station
router.get('/:station', async (req, res) => {
  try {
    const snapshot = await db.ref(`Responders/${req.params.station}`).once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch responders' });
  }
});

// Add a new station (creates a station under Responders with metadata)
router.post('/', async (req, res) => {
  try {
    const { name, streetAddress, city, region } = req.body;
    if (!name) return res.status(400).json({ error: 'Station name is required' });

    const snapshot = await db.ref(`Responders/${name}`).once('value');
    if (snapshot.exists()) {
      return res.status(400).json({ error: 'Station already exists' });
    }

    const stationData = {};
    if (streetAddress) stationData.streetAddress = streetAddress;
    if (city) stationData.city = city;
    if (region) stationData.region = region;

    await db.ref(`Responders/${name}`).set(Object.keys(stationData).length ? stationData : "");
    res.status(201).json({ message: 'Responder station created', name });
  } catch (error) {
    console.error('Failed to create responder station:', error);
    res.status(500).json({ error: 'Failed to create responder station' });
  }
});

// Add a responder
router.post('/:station', async (req, res) => {
  try {
    const responderData = req.body;
    const key = responderData.username;
    if (!key) return res.status(400).json({ error: 'Responder username is required as key' });
    const snapshot = await db.ref(`Responders/${req.params.station}/${key}`).once('value');
    if (snapshot.exists()) {
      return res.status(400).json({ error: 'Responder already exists' });
    }
    await db.ref(`Responders/${req.params.station}/${key}`).set(responderData);
    res.status(201).json({ message: 'Responder created', key });
  } catch (error) {
    console.error('Failed to create responder:', error);
    res.status(500).json({ error: 'Failed to create responder' });
  }
});

// Update a responder (handle rename)
router.put('/:station/:username', async (req, res) => {
  try {
    const oldUsername = req.params.username;
    const newUsername = req.body.username;
    const station = req.params.station;

    if (!newUsername) {
      return res.status(400).json({ error: 'Username is required' });
    }

    if (oldUsername !== newUsername) {
      await db.ref(`Responders/${station}/${newUsername}`).set(req.body);
      await db.ref(`Responders/${station}/${oldUsername}`).remove();
      res.json({ message: 'Responder renamed and updated' });
    } else {
      await db.ref(`Responders/${station}/${oldUsername}`).update(req.body);
      res.json({ message: 'Responder updated' });
    }
  } catch (error) {
    console.error('Failed to update responder:', error);
    res.status(500).json({ error: 'Failed to update responder' });
  }
});

// Update station metadata
router.put('/:station', async (req, res) => {
  try {
    const { streetAddress, city, region } = req.body;
    const updates = {};
    if (streetAddress !== undefined) updates.streetAddress = streetAddress;
    if (city !== undefined) updates.city = city;
    if (region !== undefined) updates.region = region;
    await db.ref(`Responders/${req.params.station}`).update(updates);
    res.json({ message: 'Station updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update station' });
  }
});

// Delete a responder
router.delete('/:station/:username', async (req, res) => {
  try {
    await db.ref(`Responders/${req.params.station}/${req.params.username}`).remove();
    res.json({ message: 'Responder deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete responder' });
  }
});

// Delete a station under Responders
router.delete('/:station', async (req, res) => {
  try {
    await db.ref(`Responders/${req.params.station}`).remove();
    res.json({ message: 'Station deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete station' });
  }
});

module.exports = router;

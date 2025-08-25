const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// Get all Desk Officer stations
router.get('/', async (req, res) => {
  try {
    const snapshot = await db.ref('Desk Officer').once('value');
    const stations = snapshot.val() || {};
    console.log('Desk Officer stations from Firebase:', stations);
    res.json(Object.keys(stations));
  } catch (error) {
    console.error('Error fetching Desk Officer stations:', error);
    res.status(500).json({ error: 'Failed to fetch desk officer stations' });
  }
});

// Get all officers for a station
router.get('/:station', async (req, res) => {
  try {
    const snapshot = await db.ref(`Desk Officer/${req.params.station}`).once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch officers' });
  }
});

// Add a new station (creates a station under Desk Officer with metadata)
router.post('/', async (req, res) => {
  try {
    const { name, streetAddress, city, region } = req.body;
    if (!name) return res.status(400).json({ error: 'Station name is required' });

    // Check if station already exists
    const snapshot = await db.ref(`Desk Officer/${name}`).once('value');
    if (snapshot.exists()) {
      return res.status(400).json({ error: 'Station already exists' });
    }

    // Save station metadata if provided
    const stationData = {};
    if (streetAddress) stationData.streetAddress = streetAddress;
    if (city) stationData.city = city;
    if (region) stationData.region = region;

    await db.ref(`Desk Officer/${name}`).set(Object.keys(stationData).length ? stationData : null);
    res.status(201).json({ message: 'Station created', name });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create station' });
  }
});

// Add a desk officer
router.post('/:station', async (req, res) => {
  try {
    const officerData = req.body;
    const key = officerData.username;
    if (!key) return res.status(400).json({ error: 'Officer username is required as key' });
    // Check if officer already exists
    const snapshot = await db.ref(`Desk Officer/${req.params.station}/${key}`).once('value');
    if (snapshot.exists()) {
      return res.status(400).json({ error: 'Officer already exists' });
    }
    await db.ref(`Desk Officer/${req.params.station}/${key}`).set(officerData);
    res.status(201).json({ message: 'Desk Officer created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update desk officer' });
  }
});

// Update a desk officer
router.put('/:station/:username', async (req, res) => {
  try {
    const oldUsername = req.params.username;
    const newUsername = req.body.username;
    const station = req.params.station;

    if (!newUsername) {
      return res.status(400).json({ error: 'Username is required' });
    }

    if (oldUsername !== newUsername) {
      // Create new entry at new key, then delete old key
      await db.ref(`Desk Officer/${station}/${newUsername}`).set(req.body);
      await db.ref(`Desk Officer/${station}/${oldUsername}`).remove();
      res.json({ message: 'Desk Officer renamed and updated' });
    } else {
      // Just update the existing key
      await db.ref(`Desk Officer/${station}/${oldUsername}`).update(req.body);
      res.json({ message: 'Desk Officer updated' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to update desk officer' });
  }
});

// Update station metadata (streetAddress, city, region) for a station
router.put('/:station', async (req, res) => {
  try {
    const { streetAddress, city, region } = req.body;
    const updates = {};
    if (streetAddress !== undefined) updates.streetAddress = streetAddress;
    if (city !== undefined) updates.city = city;
    if (region !== undefined) updates.region = region;
    await db.ref(`Desk Officer/${req.params.station}`).update(updates);
    res.json({ message: 'Station updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update station' });
  }
});

// Delete a desk officer
router.delete('/:station/:username', async (req, res) => {
  try {
    await db.ref(`Desk Officer/${req.params.station}/${req.params.username}`).remove();
    res.json({ message: 'Desk Officer deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete desk officer' });
  }
});

// Delete a station under Desk Officer
router.delete('/:station', async (req, res) => {
  try {
    await db.ref(`Desk Officer/${req.params.station}`).remove();
    res.json({ message: 'Station deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete station' });
  }
});

module.exports = router; 
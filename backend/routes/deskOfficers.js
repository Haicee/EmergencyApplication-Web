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
    console.error('Failed to create station:', error);
    res.status(500).json({ error: 'Failed to create station' });
  }
});

// Add a desk officer
router.post('/:station', async (req, res) => {
  const station = req.params.station;
  const officerData = req.body || {};
  const username = officerData.username;
  const password = officerData.password;
  const status = officerData.status ?? 'Active';

  if (!username) {
    return res.status(400).json({ error: 'Officer username is required as key' });
  }

  if (!password) {
    return res.status(400).json({ error: 'Officer password is required' });
  }

  try {
    const officerPath = `Desk Officer/${station}/${username}`;
    const authPath = `AuthAccounts/${username}`;

    const [existingOfficerSnapshot, existingAuthSnapshot] = await Promise.all([
      db.ref(officerPath).once('value'),
      db.ref(authPath).once('value')
    ]);

    if (existingOfficerSnapshot.exists()) {
      return res.status(400).json({ error: 'Officer already exists in this station' });
    }

    if (existingAuthSnapshot.exists()) {
      return res.status(400).json({ error: 'Auth account with this username already exists' });
    }

    const timestamp = Date.now();
    const storedOfficer = {
      ...officerData,
      username,
      status,
      createdAt: officerData.createdAt || timestamp,
      updatedAt: timestamp
    };

    const authPayload = {
      username,
      password,
      role: 'Desk Officer',
      station,
      status,
      createdAt: timestamp,
      updatedAt: timestamp
    };

    await db.ref().update({
      [officerPath]: storedOfficer,
      [authPath]: authPayload
    });

    res.status(201).json({ message: 'Desk Officer created', key: username });
  } catch (error) {
    console.error('Failed to create desk officer:', error);
    res.status(500).json({ error: 'Failed to create/update desk officer' });
  }
});

// Update a desk officer
router.put('/:station/:username', async (req, res) => {
  const station = req.params.station;
  const oldUsername = req.params.username;
  const payload = req.body || {};
  const newUsername = payload.username || oldUsername;

  try {
    const officerPath = `Desk Officer/${station}/${oldUsername}`;
    const authPath = `AuthAccounts/${oldUsername}`;

    const [officerSnapshot, authSnapshot] = await Promise.all([
      db.ref(officerPath).once('value'),
      db.ref(authPath).once('value')
    ]);

    if (!officerSnapshot.exists()) {
      return res.status(404).json({ error: 'Desk officer not found' });
    }

    if (oldUsername !== newUsername) {
      const [newOfficerSnapshot, newAuthSnapshot] = await Promise.all([
        db.ref(`Desk Officer/${station}/${newUsername}`).once('value'),
        db.ref(`AuthAccounts/${newUsername}`).once('value')
      ]);

      if (newOfficerSnapshot.exists()) {
        return res.status(400).json({ error: 'New desk officer username already exists in this station' });
      }

      if (newAuthSnapshot.exists()) {
        return res.status(400).json({ error: 'Auth account with the new username already exists' });
      }
    }

    const existingOfficer = officerSnapshot.val() || {};
    const existingAuth = authSnapshot.val() || {};
    const timestamp = Date.now();
    const mergedOfficer = {
      ...existingOfficer,
      ...payload,
      username: newUsername,
      updatedAt: timestamp
    };

    const authPayload = {
      username: newUsername,
      password: payload.password ?? existingOfficer.password ?? existingAuth.password ?? '',
      role: 'Desk Officer',
      station,
      status: payload.status ?? existingOfficer.status ?? existingAuth.status ?? 'Active',
      createdAt: existingAuth.createdAt || timestamp,
      updatedAt: timestamp
    };

    const updates = {};

    if (oldUsername !== newUsername) {
      updates[`Desk Officer/${station}/${newUsername}`] = mergedOfficer;
      updates[`Desk Officer/${station}/${oldUsername}`] = null;
      updates[`AuthAccounts/${newUsername}`] = authPayload;
      updates[`AuthAccounts/${oldUsername}`] = null;
    } else {
      updates[`Desk Officer/${station}/${oldUsername}`] = mergedOfficer;
      updates[`AuthAccounts/${oldUsername}`] = authPayload;
    }

    await db.ref().update(updates);

    res.json({ message: 'Desk Officer updated' });
  } catch (error) {
    console.error('Failed to update desk officer:', error);
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
  const station = req.params.station;
  const username = req.params.username;

  try {
    const officerPath = `Desk Officer/${station}/${username}`;
    const officerSnapshot = await db.ref(officerPath).once('value');

    if (!officerSnapshot.exists()) {
      return res.status(404).json({ error: 'Desk officer not found' });
    }

    await db.ref().update({
      [officerPath]: null,
      [`AuthAccounts/${username}`]: null
    });

    res.json({ message: 'Desk Officer deleted' });
  } catch (error) {
    console.error('Failed to delete desk officer:', error);
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
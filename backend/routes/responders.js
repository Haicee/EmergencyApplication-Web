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
  const station = req.params.station;
  const responderData = req.body;
  const username = responderData?.username;
  const password = responderData?.password;
  const status = responderData?.status || 'Active';

  if (!username) {
    return res.status(400).json({ error: 'Responder username is required as key' });
  }

  if (!password) {
    return res.status(400).json({ error: 'Responder password is required' });
  }

  try {
    const responderPath = `Responders/${station}/${username}`;
    const authPath = `AuthAccounts/${username}`;

    const [existingResponderSnapshot, existingAuthSnapshot] = await Promise.all([
      db.ref(responderPath).once('value'),
      db.ref(authPath).once('value')
    ]);

    if (existingResponderSnapshot.exists()) {
      return res.status(400).json({ error: 'Responder already exists in this station' });
    }

    if (existingAuthSnapshot.exists()) {
      return res.status(400).json({ error: 'Auth account with this username already exists' });
    }

    const timestamp = Date.now();
    const authPayload = {
      username,
      password,
      role: 'Responder',
      station,
      status,
      createdAt: timestamp,
      updatedAt: timestamp
    };

    await db.ref().update({
      [responderPath]: responderData,
      [authPath]: authPayload
    });

    res.status(201).json({ message: 'Responder created', key: username });
  } catch (error) {
    console.error('Failed to create responder:', error);
    res.status(500).json({ error: 'Failed to create responder' });
  }
});

// Update a responder (handle rename and AuthAccounts sync)
router.put('/:station/:username', async (req, res) => {
  const station = req.params.station;
  const oldUsername = req.params.username;
  const payload = req.body || {};
  const newUsername = payload.username || oldUsername;

  try {
    const responderPath = `Responders/${station}/${oldUsername}`;
    const authPath = `AuthAccounts/${oldUsername}`;

    const [responderSnapshot, authSnapshot] = await Promise.all([
      db.ref(responderPath).once('value'),
      db.ref(authPath).once('value')
    ]);

    if (!responderSnapshot.exists()) {
      return res.status(404).json({ error: 'Responder not found' });
    }

    if (oldUsername !== newUsername) {
      const [newResponderSnapshot, newAuthSnapshot] = await Promise.all([
        db.ref(`Responders/${station}/${newUsername}`).once('value'),
        db.ref(`AuthAccounts/${newUsername}`).once('value')
      ]);

      if (newResponderSnapshot.exists()) {
        return res.status(400).json({ error: 'New responder username already exists in this station' });
      }

      if (newAuthSnapshot.exists()) {
        return res.status(400).json({ error: 'Auth account with the new username already exists' });
      }
    }

    const existingResponder = responderSnapshot.val() || {};
    const existingAuth = authSnapshot.val() || {};
    const timestamp = Date.now();
    const mergedResponder = {
      ...existingResponder,
      ...payload,
      username: newUsername,
      updatedAt: timestamp
    };

    const authPayload = {
      username: newUsername,
      password: payload.password ?? existingResponder.password ?? existingAuth.password ?? '',
      role: 'Responder',
      station,
      status: payload.status ?? existingResponder.status ?? existingAuth.status ?? 'Active',
      createdAt: existingAuth.createdAt || timestamp,
      updatedAt: timestamp
    };

    const updates = {};

    if (oldUsername !== newUsername) {
      updates[`Responders/${station}/${newUsername}`] = mergedResponder;
      updates[`Responders/${station}/${oldUsername}`] = null;
      updates[`AuthAccounts/${newUsername}`] = authPayload;
      updates[`AuthAccounts/${oldUsername}`] = null;
    } else {
      updates[`Responders/${station}/${oldUsername}`] = mergedResponder;
      updates[`AuthAccounts/${oldUsername}`] = authPayload;
    }

    await db.ref().update(updates);

    res.json({ message: 'Responder updated' });
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
  const station = req.params.station;
  const username = req.params.username;

  try {
    const responderPath = `Responders/${station}/${username}`;
    const responderSnapshot = await db.ref(responderPath).once('value');

    if (!responderSnapshot.exists()) {
      return res.status(404).json({ error: 'Responder not found' });
    }

    await db.ref().update({
      [responderPath]: null,
      [`AuthAccounts/${username}`]: null
    });

    res.json({ message: 'Responder deleted' });
  } catch (error) {
    console.error('Failed to delete responder:', error);
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

const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// USERS CRUD (keyed by full name)
router.get('/', async (req, res) => {
  try {
    const snapshot = await db.ref('users').once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

router.get('/:username', async (req, res) => {
  try {
    const snapshot = await db.ref(`users/${req.params.username}`).once('value');
    const user = snapshot.val();
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

router.post('/', async (req, res) => {
  try {
    const userData = req.body;
    const key = userData.username || userData.fullName || userData.name;
    if (!key) return res.status(400).json({ error: 'Username/fullName is required as key' });
    await db.ref(`users/${key}`).set(userData);
    res.status(201).json({ message: 'User created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update user' });
  }
});

router.put('/:username', async (req, res) => {
  try {
    await db.ref(`users/${req.params.username}`).update(req.body);
    res.json({ message: 'User updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update user' });
  }
});

router.delete('/:username', async (req, res) => {
  try {
    await db.ref(`users/${req.params.username}`).remove();
    res.json({ message: 'User deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// CITIZENS CRUD operations (for frontend compatibility)
router.get('/citizens', async (req, res) => {
  try {
    const snapshot = await db.ref('users').once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch citizens' });
  }
});

router.get('/citizens/:id', async (req, res) => {
  try {
    const snapshot = await db.ref(`users/${req.params.id}`).once('value');
    const citizen = snapshot.val();
    if (!citizen) return res.status(404).json({ error: 'Citizen not found' });
    res.json(citizen);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch citizen' });
  }
});

router.post('/citizens', async (req, res) => {
  try {
    const citizenData = req.body;
    const key = citizenData.username || citizenData.fullName || citizenData.name;
    if (!key) return res.status(400).json({ error: 'Username/fullName is required as key' });
    await db.ref(`users/${key}`).set(citizenData);
    res.status(201).json({ message: 'Citizen created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update citizen' });
  }
});

router.put('/citizens/:id', async (req, res) => {
  try {
    const oldId = req.params.id;
    const newId = req.body.username || req.body.fullName || req.body.name;
    if (!newId) return res.status(400).json({ error: 'Username/fullName is required as key' });

    if (oldId !== newId) {
      // Copy to new key, then delete old key
      await db.ref(`users/${newId}`).set(req.body);
      await db.ref(`users/${oldId}`).remove();
      res.json({ message: 'Citizen renamed and updated' });
    } else {
      await db.ref(`users/${oldId}`).update(req.body);
      res.json({ message: 'Citizen updated' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to update citizen' });
  }
});

router.delete('/citizens/:id', async (req, res) => {
  try {
    await db.ref(`users/${req.params.id}`).remove();
    res.json({ message: 'Citizen deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete citizen' });
  }
});

// STATIONS CRUD operations
router.get('/stations', async (req, res) => {
  try {
    const snapshot = await db.ref('stations').once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch stations' });
  }
});

router.get('/stations/:id', async (req, res) => {
  try {
    const snapshot = await db.ref(`stations/${req.params.id}`).once('value');
    const station = snapshot.val();
    if (!station) return res.status(404).json({ error: 'Station not found' });
    res.json(station);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch station' });
  }
});

router.post('/stations', async (req, res) => {
  try {
    const stationData = req.body;
    const key = stationData.id || stationData.name;
    if (!key) return res.status(400).json({ error: 'Station ID/name is required as key' });
    await db.ref(`stations/${key}`).set(stationData);
    res.status(201).json({ message: 'Station created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update station' });
  }
});

router.put('/stations/:id', async (req, res) => {
  try {
    await db.ref(`stations/${req.params.id}`).update(req.body);
    res.json({ message: 'Station updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update station' });
  }
});

router.delete('/stations/:id', async (req, res) => {
  try {
    await db.ref(`stations/${req.params.id}`).remove();
    res.json({ message: 'Station deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete station' });
  }
});

// OFFICERS CRUD operations (nested under stations)
router.post('/stations/:stationId/officers', async (req, res) => {
  try {
    const officerData = req.body;
    const key = officerData.id || officerData.initials || officerData.name;
    if (!key) return res.status(400).json({ error: 'Officer ID/initials/name is required as key' });
    await db.ref(`stations/${req.params.stationId}/officers/${key}`).set(officerData);
    res.status(201).json({ message: 'Officer created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update officer' });
  }
});

router.put('/stations/:stationId/officers/:officerId', async (req, res) => {
  try {
    await db.ref(`stations/${req.params.stationId}/officers/${req.params.officerId}`).update(req.body);
    res.json({ message: 'Officer updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update officer' });
  }
});

router.delete('/stations/:stationId/officers/:officerId', async (req, res) => {
  try {
    await db.ref(`stations/${req.params.stationId}/officers/${req.params.officerId}`).remove();
    res.json({ message: 'Officer deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete officer' });
  }
});

// DESK OFFICERS CRUD (keyed by username under station)
router.get('/desk-officers', async (req, res) => {
  try {
    const snapshot = await db.ref('Desk Officer').once('value');
    const stations = snapshot.val() || {};
    res.json(Object.keys(stations));
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch desk officer stations' });
  }
});

router.get('/desk-officers/:station', async (req, res) => {
  try {
    const snapshot = await db.ref(`Desk Officer/${req.params.station}`).once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch officers' });
  }
});

router.get('/desk-officers/:station/:username', async (req, res) => {
  try {
    const snapshot = await db.ref(`Desk Officer/${req.params.station}/${req.params.username}`).once('value');
    const officer = snapshot.val();
    if (!officer) return res.status(404).json({ error: 'Officer not found' });
    res.json(officer);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch officer' });
  }
});

router.post('/desk-officers/:station', async (req, res) => {
  try {
    const officerData = req.body;
    const key = officerData.username;
    if (!key) return res.status(400).json({ error: 'Officer username is required as key' });
    await db.ref(`Desk Officer/${req.params.station}/${key}`).set(officerData);
    res.status(201).json({ message: 'Officer created/updated', key });
  } catch (error) {
    res.status(500).json({ error: 'Failed to create/update officer' });
  }
});

router.put('/desk-officers/:station/:username', async (req, res) => {
  try {
    await db.ref(`Desk Officer/${req.params.station}/${req.params.username}`).update(req.body);
    res.json({ message: 'Officer updated' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update officer' });
  }
});

router.delete('/desk-officers/:station/:username', async (req, res) => {
  try {
    await db.ref(`Desk Officer/${req.params.station}/${req.params.username}`).remove();
    res.json({ message: 'Officer deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete officer' });
  }
});

module.exports = router; 
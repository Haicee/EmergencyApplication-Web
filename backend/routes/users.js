const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

const USERS_NODE = 'users';
const AUTH_NODE = 'AuthAccounts';
const DEFAULT_ROLE = 'Citizen';
const DEFAULT_STATUS = 'Active';

const getUserKey = (data = {}) => data.username || data.fullName || data.name;

const createHttpError = (status, message) => {
  const error = new Error(message);
  error.status = status;
  return error;
};

const handleError = (res, error, fallbackMessage) => {
  if (error?.status) {
    return res.status(error.status).json({ error: error.message });
  }
  console.error(fallbackMessage, error);
  return res.status(500).json({ error: fallbackMessage });
};

async function createUserRecord(data = {}, { forceRole, defaultStatus } = {}) {
  const key = getUserKey(data);
  if (!key) throw createHttpError(400, 'Username/fullName is required as key');
  if (!data.password) throw createHttpError(400, 'Password is required');

  const role = forceRole || data.role || DEFAULT_ROLE;
  const status = data.status || defaultStatus || DEFAULT_STATUS;
  const timestamp = Date.now();
  const createdAt = data.createdAt || timestamp;

  const storedUser = {
    ...data,
    username: key,
    role,
    status,
    createdAt,
    updatedAt: timestamp
  };

  const authPayload = {
    username: key,
    password: data.password,
    role,
    status,
    createdAt,
    updatedAt: timestamp
  };

  await db.ref().update({
    [`${USERS_NODE}/${key}`]: storedUser,
    [`${AUTH_NODE}/${key}`]: authPayload
  });

  return key;
}

async function updateUserRecord(oldKey, data = {}, { forceRole, defaultStatus } = {}) {
  const newKey = getUserKey(data) || oldKey;

  const userRef = db.ref(`${USERS_NODE}/${oldKey}`);
  const authRef = db.ref(`${AUTH_NODE}/${oldKey}`);

  const [userSnapshot, authSnapshot] = await Promise.all([
    userRef.once('value'),
    authRef.once('value')
  ]);

  if (!userSnapshot.exists()) {
    throw createHttpError(404, 'User not found');
  }

  if (oldKey !== newKey) {
    const [newUserSnapshot, newAuthSnapshot] = await Promise.all([
      db.ref(`${USERS_NODE}/${newKey}`).once('value'),
      db.ref(`${AUTH_NODE}/${newKey}`).once('value')
    ]);

    if (newUserSnapshot.exists()) {
      throw createHttpError(400, 'New username already exists');
    }

    if (newAuthSnapshot.exists()) {
      throw createHttpError(400, 'Auth account with the new username already exists');
    }
  }

  const existingUser = userSnapshot.val() || {};
  const existingAuth = authSnapshot.val() || {};

  const timestamp = Date.now();
  const role = forceRole || data.role || existingUser.role || existingAuth.role || DEFAULT_ROLE;
  const status =
    data.status ??
    existingUser.status ??
    existingAuth.status ??
    (defaultStatus ?? DEFAULT_STATUS);
  const createdAt = existingUser.createdAt || existingAuth.createdAt || timestamp;
  const password = data.password ?? existingUser.password ?? existingAuth.password ?? '';

  const mergedUser = {
    ...existingUser,
    ...data,
    username: newKey,
    role,
    status,
    createdAt,
    updatedAt: timestamp
  };

  const authPayload = {
    username: newKey,
    password,
    role,
    status,
    createdAt,
    updatedAt: timestamp
  };

  const updates = {};

  if (oldKey !== newKey) {
    updates[`${USERS_NODE}/${newKey}`] = mergedUser;
    updates[`${USERS_NODE}/${oldKey}`] = null;
    updates[`${AUTH_NODE}/${newKey}`] = authPayload;
    updates[`${AUTH_NODE}/${oldKey}`] = null;
  } else {
    updates[`${USERS_NODE}/${oldKey}`] = mergedUser;
    updates[`${AUTH_NODE}/${oldKey}`] = authPayload;
  }

  await db.ref().update(updates);

  return newKey;
}

async function deleteUserRecord(key) {
  const userPath = `${USERS_NODE}/${key}`;
  const snapshot = await db.ref(userPath).once('value');

  if (!snapshot.exists()) {
    throw createHttpError(404, 'User not found');
  }

  await db.ref().update({
    [userPath]: null,
    [`${AUTH_NODE}/${key}`]: null
  });
}

// USERS CRUD (keyed by full name)
router.get('/', async (req, res) => {
  try {
    const snapshot = await db.ref(USERS_NODE).once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

router.post('/', async (req, res) => {
  try {
    const key = await createUserRecord(req.body, {});
    res.status(201).json({ message: 'User created/updated', key });
  } catch (error) {
    handleError(res, error, 'Failed to create/update user');
  }
});

router.get('/citizens', async (req, res) => {
  try {
    const snapshot = await db.ref(USERS_NODE).once('value');
    res.json(snapshot.val() || {});
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch citizens' });
  }
});

router.get('/citizens/:id', async (req, res) => {
  try {
    const snapshot = await db.ref(`${USERS_NODE}/${req.params.id}`).once('value');
    const citizen = snapshot.val();
    if (!citizen) return res.status(404).json({ error: 'Citizen not found' });
    res.json(citizen);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch citizen' });
  }
});

router.post('/citizens', async (req, res) => {
  try {
    const key = await createUserRecord(
      { ...req.body, role: req.body?.role || DEFAULT_ROLE },
      { forceRole: DEFAULT_ROLE, defaultStatus: DEFAULT_STATUS }
    );
    res.status(201).json({ message: 'Citizen created/updated', key });
  } catch (error) {
    handleError(res, error, 'Failed to create/update citizen');
  }
});

router.put('/citizens/:id', async (req, res) => {
  try {
    const newKey = await updateUserRecord(
      req.params.id,
      { ...req.body, role: req.body?.role || DEFAULT_ROLE },
      { forceRole: DEFAULT_ROLE, defaultStatus: DEFAULT_STATUS }
    );
    res.json({ message: 'Citizen updated', key: newKey });
  } catch (error) {
    handleError(res, error, 'Failed to update citizen');
  }
});

router.delete('/citizens/:id', async (req, res) => {
  try {
    await deleteUserRecord(req.params.id);
    res.json({ message: 'Citizen deleted' });
  } catch (error) {
    handleError(res, error, 'Failed to delete citizen');
  }
});

router.get('/:username', async (req, res) => {
  try {
    const snapshot = await db.ref(`${USERS_NODE}/${req.params.username}`).once('value');
    const user = snapshot.val();
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

router.put('/:username', async (req, res) => {
  try {
    const newKey = await updateUserRecord(req.params.username, req.body, {});
    res.json({ message: 'User updated', key: newKey });
  } catch (error) {
    handleError(res, error, 'Failed to update user');
  }
});

router.delete('/:username', async (req, res) => {
  try {
    await deleteUserRecord(req.params.username);
    res.json({ message: 'User deleted' });
  } catch (error) {
    handleError(res, error, 'Failed to delete user');
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
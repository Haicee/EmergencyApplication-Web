const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');

// POST /api/auth/login
// Simple username/password check against AuthAccounts
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    // Firebase RTDB keys cannot contain '.'; use a safe key
    const safeKey = String(username).replace(/\./g, ',');
    const snapshot = await db.ref(`AuthAccounts/${safeKey}`).once('value');
    if (!snapshot.exists()) return res.status(401).json({ error: 'Invalid credentials' });

    const acct = snapshot.val() || {};
    if (acct.password !== password) return res.status(401).json({ error: 'Invalid credentials' });

    if ((acct.status || 'Active') === 'Inactive') {
      return res.status(403).json({ error: 'Account is inactive' });
    }

    // Only allow Admins to access the Admin Dashboard
    if (acct.role !== 'Admin') {
      return res.status(403).json({ error: 'Admin access only' });
    }

    // In a real app, issue a JWT. For now, return account summary.
    return res.json({
      username: acct.username,
      role: acct.role,
      station: acct.station || null,
      status: acct.status || 'Active'
    });
  } catch (err) {
    console.error('Login failed:', err);
    return res.status(500).json({ error: 'Failed to login' });
  }
});

// POST /api/auth/bootstrap-admin
// Create an initial Admin account, protected by a setup token
router.post('/bootstrap-admin', async (req, res) => {
  try {
    const token = req.header('x-admin-setup-token');
    if (!token || token !== process.env.ADMIN_SETUP_TOKEN) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { username, password, fullName } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ error: 'username and password are required' });
    }

    const safeKey = String(username).replace(/\./g, ',');
    const ref = db.ref(`AuthAccounts/${safeKey}`);
    const snap = await ref.once('value');
    if (snap.exists()) {
      return res.status(400).json({ error: 'Account already exists' });
    }

    const timestamp = Date.now();
    const adminRecord = {
      username,
      password,
      role: 'Admin',
      status: 'Active',
      createdAt: timestamp,
      updatedAt: timestamp
    };

    // Also mirror into generic users collection for consistency
    const userRecord = {
      username,
      fullName: fullName || username,
      role: 'Admin',
      status: 'Active',
      password,
      createdAt: timestamp,
      updatedAt: timestamp
    };

    await db.ref().update({
      [`AuthAccounts/${safeKey}`]: adminRecord,
      [`users/${safeKey}`]: userRecord
    });

    return res.status(201).json({ message: 'Admin account created', username });
  } catch (err) {
    console.error('Bootstrap admin failed:', err);
    return res.status(500).json({ error: 'Failed to create admin account' });
  }
});

module.exports = router;

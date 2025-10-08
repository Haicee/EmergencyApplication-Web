require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const usersRoutes = require('./routes/users');
const deskOfficersRoutes = require('./routes/deskOfficers');
const respondersRoutes = require('./routes/responders');
const emergencyCallsRoutes = require('./routes/emergencyCalls');
const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/users', usersRoutes);
app.use('/api/desk-officers', deskOfficersRoutes);
app.use('/api/responders', respondersRoutes);
app.use('/api/emergency-calls', emergencyCallsRoutes);
app.use('/api/auth', authRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'ResME Backend Server is running',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'ResME Emergency Management System Backend',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      users: '/api/users',
      deskOfficers: '/api/desk-officers',
      responders: '/api/responders',
      emergencyCalls: '/api/emergency-calls',
      auth: '/api/auth'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`🚀 ResME Backend Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔗 API Base URL: http://localhost:${PORT}/api`);
});

module.exports = app; 
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🚀 ResME Emergency Management System Setup');
console.log('==========================================\n');

// Check if Node.js is installed
try {
  const nodeVersion = process.version;
  console.log(`✅ Node.js version: ${nodeVersion}`);
  
  if (parseInt(nodeVersion.slice(1).split('.')[0]) < 14) {
    console.log('❌ Node.js version 14 or higher is required');
    process.exit(1);
  }
} catch (error) {
  console.log('❌ Node.js is not installed');
  process.exit(1);
}

// Check if npm is available
try {
  const npmVersion = execSync('npm --version', { encoding: 'utf8' }).trim();
  console.log(`✅ npm version: ${npmVersion}`);
} catch (error) {
  console.log('❌ npm is not available');
  process.exit(1);
}

// Create backend directory if it doesn't exist
const backendDir = path.join(__dirname, 'backend');
if (!fs.existsSync(backendDir)) {
  console.log('📁 Creating backend directory...');
  fs.mkdirSync(backendDir, { recursive: true });
}

// Create config directory
const configDir = path.join(backendDir, 'config');
if (!fs.existsSync(configDir)) {
  console.log('📁 Creating config directory...');
  fs.mkdirSync(configDir, { recursive: true });
}

// Create routes directory
const routesDir = path.join(backendDir, 'routes');
if (!fs.existsSync(routesDir)) {
  console.log('📁 Creating routes directory...');
  fs.mkdirSync(routesDir, { recursive: true });
}

// Create services directory in frontend
const servicesDir = path.join(__dirname, 'my-app', 'src', 'services');
if (!fs.existsSync(servicesDir)) {
  console.log('📁 Creating services directory...');
  fs.mkdirSync(servicesDir, { recursive: true });
}

console.log('\n📦 Installing backend dependencies...');
try {
  execSync('npm install', { cwd: backendDir, stdio: 'inherit' });
  console.log('✅ Backend dependencies installed');
} catch (error) {
  console.log('❌ Failed to install backend dependencies');
  process.exit(1);
}

console.log('\n📦 Installing frontend dependencies...');
try {
  execSync('npm install', { cwd: path.join(__dirname, 'my-app'), stdio: 'inherit' });
  console.log('✅ Frontend dependencies installed');
} catch (error) {
  console.log('❌ Failed to install frontend dependencies');
  process.exit(1);
}

console.log('\n🔧 Setup Instructions:');
console.log('=====================');
console.log('1. Get your Firebase service account key from Firebase Console');
console.log('2. Create a .env file in the backend directory with your Firebase credentials');
console.log('3. Start the backend: cd backend && npm run dev');
console.log('4. Start the frontend: cd my-app && npm start');
console.log('\n📖 See README.md for detailed setup instructions');

console.log('\n✅ Setup completed successfully!'); 
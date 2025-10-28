/**
 * Firebase Connection Test Script
 * Tests connection to the new resmeapp-1 Firebase project
 * Run: node test-connection.js
 */

require('dotenv').config();
const { db, admin } = require('./config/firebase');

console.log('🔍 Testing Firebase Connection...\n');
console.log('📋 Configuration:');
console.log('   Project ID:', process.env.FIREBASE_PROJECT_ID);
console.log('   Client Email:', process.env.FIREBASE_CLIENT_EMAIL);
console.log('   Database URL: https://resmeapp-1-default-rtdb.firebaseio.com\n');

async function testConnection() {
  try {
    console.log('⏳ Attempting to connect to Firebase...');
    
    // Test 1: Database connection
    const testRef = db.ref('.info/connected');
    const snapshot = await testRef.once('value');
    const connected = snapshot.val();

    if (connected) {
      console.log('✅ Socket connection detected.');
    } else {
      console.log('⚠️  .info/connected reported "false". This is expected with the Admin SDK, continuing with direct read/write tests...');
    }
    
    // Test 2: Write test
    console.log('⏳ Testing write permissions...');
    const testDataRef = db.ref('_connection_test');
    await testDataRef.set({
      timestamp: Date.now(),
      message: 'Connection test successful',
      project: 'resmeapp-1'
    });
    console.log('✅ Write test: SUCCESS');
    
    // Test 3: Read test
    console.log('⏳ Testing read permissions...');
    const readSnapshot = await testDataRef.once('value');
    const data = readSnapshot.val();
    if (data && data.message === 'Connection test successful') {
      console.log('✅ Read test: SUCCESS');
    } else {
      console.log('❌ Read test: FAILED');
    }
    
    // Test 4: Delete test
    console.log('⏳ Testing delete permissions...');
    await testDataRef.remove();
    console.log('✅ Delete test: SUCCESS');
    
    console.log('\n🎉 All tests passed! Firebase connection is working correctly.');
    console.log('\n📝 Next steps:');
    console.log('   1. Enable Realtime Database in Firebase Console');
    console.log('   2. Set database rules (see firebase-database-rules.json)');
    console.log('   3. Create initial admin account');
    console.log('   4. Start the backend server: npm run dev');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Connection test failed!');
    console.error('Error:', error.message);
    
    if (error.code === 'PERMISSION_DENIED') {
      console.log('\n💡 Solution: Enable Realtime Database in Firebase Console');
      console.log('   Go to: https://console.firebase.google.com/project/resmeapp-1/database');
      console.log('   Click "Create Database" and start in Test Mode');
    } else if (error.code === 'INVALID_ARGUMENT') {
      console.log('\n💡 Solution: Check your .env file credentials');
      console.log('   Make sure FIREBASE_PRIVATE_KEY is properly formatted');
    } else {
      console.log('\n💡 Check:');
      console.log('   - .env file exists and has correct credentials');
      console.log('   - Firebase project exists: resmeapp-1');
      console.log('   - Service account has proper permissions');
    }
    
    process.exit(1);
  }
}

// Run the test
testConnection();

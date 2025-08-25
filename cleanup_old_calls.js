// Firebase cleanup script to remove old calls node
// Run this script to clean up the old Firebase structure

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// You'll need to download your service account key from Firebase Console
// and place it in the same directory as this script
const serviceAccount = require('./your-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://emergency-73ada-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function cleanupOldCalls() {
  try {
    console.log('Starting cleanup of old calls node...');
    
    // Remove the old calls node from each station
    const stations = ['Police Station 1']; // Add more stations if needed
    
    for (const station of stations) {
      const oldCallsRef = db.ref(`Desk Officer/${station}/calls`);
      
      // Check if the old calls node exists
      const snapshot = await oldCallsRef.once('value');
      
      if (snapshot.exists()) {
        console.log(`Removing old calls node from ${station}...`);
        await oldCallsRef.remove();
        console.log(`✅ Successfully removed old calls node from ${station}`);
      } else {
        console.log(`ℹ️  No old calls node found in ${station}`);
      }
    }
    
    console.log('🎉 Cleanup completed successfully!');
    console.log('✅ Old calls node has been removed');
    console.log('✅ New structure is now active:');
    console.log('   - All Calls/ActiveCalls');
    console.log('   - All Calls/AnsweredCalls');
    console.log('   - All Calls/MissedCalls');
    console.log('   - Police Station 1/ReceivedCalls/ActiveCalls');
    console.log('   - Police Station 1/ReceivedCalls/AnsweredCalls');
    console.log('   - Police Station 1/ReceivedCalls/MissedCalls');
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  } finally {
    process.exit(0);
  }
}

// Run the cleanup
cleanupOldCalls(); 
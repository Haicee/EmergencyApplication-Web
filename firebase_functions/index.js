const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Sends an incoming call notification when a new ActiveCall is created for a user
exports.notifyIncomingCall = functions.database
  .ref('/users/{username}/ReceivedCalls/ActiveCalls/{callId}')
  .onCreate(async (snapshot, context) => {
    const { username, callId } = context.params;
    const callData = snapshot.val() || {};

    try {
      // Read user fcmToken
      const userSnap = await admin.database().ref(`/users/${username}/fcmToken`).get();
      const token = userSnap.exists() ? userSnap.val() : null;
      if (!token) {
        console.log(`No FCM token for user ${username}`);
        return null;
      }

      const station = callData.station || 'Police Station';
      const title = `${station} is calling`;
      const body = 'Tap to answer the emergency callback';

      const message = {
        token,
        android: {
          priority: 'high',
          notification: {
            channelId: 'emergency_calls',
            sound: 'default',
            priority: 'max',
            visibility: 'public',
          },
        },
        data: {
          type: 'incoming_call',
          username: username,
          callId: callId,
          station: station,
          hotline: String(callData.hotline || ''),
        },
        notification: {
          title,
          body,
        },
      };

      await admin.messaging().send(message);
      console.log(`Incoming call notification sent to ${username} for call ${callId}`);
      return null;
    } catch (e) {
      console.error('Error sending incoming call notification', e);
      return null;
    }
  });

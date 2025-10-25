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

// Notifies all active responders of a station when Desk Officer assigns a task
exports.notifyResponderAssignment = functions.database
  .ref('/Responders/{stationName}/ReceivedCallDetails/Assigned/{callId}')
  .onCreate(async (snapshot, context) => {
    const { stationName, callId } = context.params;
    const taskData = snapshot.val() || {};

    try {
      // Collect responder tokens under the station
      const respondersSnap = await admin
        .database()
        .ref(`/Responders/${stationName}`)
        .get();

      if (!respondersSnap.exists()) {
        console.log(`No responders found for station ${stationName}`);
        return null;
      }

      const tokens = new Set();
      respondersSnap.forEach((child) => {
        const v = child.val() || {};
        const status = v.status || 'Inactive';
        const token = v.fcmToken || null;
        if (status === 'Active' && token && typeof token === 'string') {
          tokens.add(token);
        }
      });

      if (tokens.size === 0) {
        console.log(`No active responder tokens for station ${stationName}`);
        return null;
      }

      const title = `New Assignment`;
      const body = `${taskData.callerName || 'Citizen'} needs assistance`;

      const message = {
        tokens: Array.from(tokens),
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
          type: 'incoming_emergency',
          callId: String(callId),
          station: String(stationName),
          username: String(taskData.callerName || 'Citizen'),
          streetAddress: String(taskData.location || ''),
          city: String(taskData.city || ''),
          region: String(taskData.region || ''),
        },
        notification: {
          title,
          body,
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Responder notify: station=${stationName} call=${callId} tokens=${tokens.size} success=${response.successCount} failure=${response.failureCount}`
      );
      return null;
    } catch (e) {
      console.error('Error sending responder assignment notification', e);
      return null;
    }
  });

// Notifies all active desk officers of a station when a citizen creates an ActiveCall
exports.notifyStationIncomingEmergency = functions.database
  .ref('/Desk Officer/{stationName}/ReceivedCalls/ActiveCalls/{callId}')
  .onCreate(async (snapshot, context) => {
    const { stationName, callId } = context.params;
    const callData = snapshot.val() || {};

    try {
      // Read officers under the station and collect FCM tokens for active officers
      const officersSnap = await admin
        .database()
        .ref(`/Desk Officer/${stationName}`)
        .get();

      if (!officersSnap.exists()) {
        console.log(`No officers found for station ${stationName}`);
        return null;
      }

      const tokens = new Set();
      officersSnap.forEach((officerChild) => {
        const officer = officerChild.val() || {};
        const status = officer.status || 'Inactive';
        const token = officer.fcmToken || null;
        if (status === 'Active' && token && typeof token === 'string') {
          tokens.add(token);
        }
      });

      if (tokens.size === 0) {
        console.log(`No active officer tokens for station ${stationName}`);
        return null;
      }

      // Exclude citizen's own token if the same device was also registered under the station
      try {
        const caller = String(callData.caller || callData.username || callData.citizen || '');
        if (caller) {
          const citizenTokenSnap = await admin.database().ref(`/users/${caller}/fcmToken`).get();
          if (citizenTokenSnap.exists()) {
            const citizenToken = citizenTokenSnap.val();
            if (citizenToken && typeof citizenToken === 'string' && tokens.has(citizenToken)) {
              tokens.delete(citizenToken);
              console.log(`Excluded citizen token from officer multicast for caller=${caller}`);
            }
          }
        }
      } catch (excludeErr) {
        console.log('Could not exclude citizen token (non-fatal):', excludeErr?.message || excludeErr);
      }

      const citizenUsername = String(callData.caller || callData.username || callData.citizen || 'Citizen');
      const addressParts = [
        callData.streetAddress,
        callData.city,
        callData.region,
      ]
        .filter((p) => typeof p === 'string' && p.length > 0)
        .join(', ');

      const title = `${citizenUsername} is calling`;
      const body = 'Tap to answer the emergency call';

      const message = {
        tokens: Array.from(tokens),
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
          type: 'incoming_emergency',
          callId: String(callId),
          station: String(stationName),
          username: String(citizenUsername),
          streetAddress: String(callData.streetAddress || ''),
          city: String(callData.city || ''),
          region: String(callData.region || ''),
        },
        notification: {
          title,
          body,
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      const success = response.successCount || 0;
      const failure = response.failureCount || 0;
      console.log(
        `Officer notify: station=${stationName} call=${callId} tokens=${tokens.size} success=${success} failure=${failure}`
      );

      return null;
    } catch (e) {
      console.error('Error sending station incoming emergency notification', e);
      return null;
    }
  });

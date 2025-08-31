const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require("agora-token");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

// ========== Agora Token Generation ==========
exports.generateToken = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { channelName, uid, userRole } = data;

    // Validate input
    if (!channelName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'channelName is required'
      );
    }

    // Get Agora credentials from environment variables
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCertificate) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Agora credentials not configured. Please set AGORA_APP_ID and AGORA_APP_CERTIFICATE environment variables.'
      );
    }

    const userId = Number(uid) || 0;
    const role = userRole === "0" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    const expireSec = 144000; // 40 hours
    const privilegeTs = Math.floor(Date.now() / 1000) + expireSec;

    // Generate Agora token
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId, 
      appCertificate, 
      channelName, 
      userId, 
      role, 
      privilegeTs
    );

    return {
      success: true,
      token: token,
      appId: appId,
      channelName: channelName,
      uid: userId,
      role: userRole,
      expireTime: privilegeTs
    };

  } catch (error) {
    console.error('Generate Agora token error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate Agora token: ' + error.message
    );
  }
});

// ========== FCM Push Notification ==========
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { fcmToken, title, body, data: customData } = data;

    // Validate input
    if (!fcmToken || !title || !body) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'fcmToken, title, and body are required'
      );
    }

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: customData || {}, // Optional custom payload
    };

    const response = await admin.messaging().send(message);
    
    return {
      success: true,
      messageId: response,
      response: response
    };

  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notification: ' + error.message
    );
  }
});

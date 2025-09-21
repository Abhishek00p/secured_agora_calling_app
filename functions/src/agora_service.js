const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const cors = require('cors')({ origin: true });

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

// ========== Verify Agora Token ==========
exports.verifyToken = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          error_message: 'Method not allowed'
        });
      }

      const { channelName, uid, userRole } = req.body;

      if (!channelName || !uid ) {
        return res.status(400).json({
          success: false,
          error_message: 'channelName and uid are required'
        });
      }

      const appId = '225a62f4b5aa4e94ab46f91d0a0257e1';
      const appCertificate = '64ba1b2a26694545aac2f5f9ed86ac09';

      if (!appId || !appCertificate) {
        return res.status(500).json({
          success: false,
          error_message: 'Agora credentials not configured.'
        });
      }

      // Fetch token and expiry from Firestore
      const meetingDoc = await admin.firestore()
        .collection('meetings')
        .doc(channelName)
        .get();

      if (!meetingDoc.exists) {
        return res.status(404).json({
          success: false,
          valid: false,
          error_message: 'Meeting not found'
        });
      }

      const { tokens } = meetingDoc.data();
      if (!tokens || !tokens[uid]) {
        return res.status(404).json({
          success: false,
          valid: false,
          error_message: 'Token not found for the given uid'
        });
      }
      
      const  token  = tokens[uid]['token'];
      const  expireTime  = tokens[uid]['expiry_time'];

      const userId = Number(uid) || 0;
      const role = userRole === "0" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
      const privilegeTs =
        expireTime || Math.floor(Date.now() / 1000) + 60; // fallback to small window

      // Recreate expected token
      const expectedToken = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        userId,
        role,
        privilegeTs
      );

      if (token !== expectedToken) {
        console.warn('Token mismatch detected');
        return res.status(401).json({
          success: false,
          valid: false,
          error_message: "{msg : 'Invalid token',\n fetchedToken: '" + token + "',\n ExpectedExpiryTime: '" + expireTime +"',currExpiryTime: '" + privilegeTs + "',\n expectedToken: '" + expectedToken + "'}"
        });
      }

      // Optionally check if token expired
      const now = Math.floor(Date.now() / 1000);
      if (privilegeTs < now) {
        return res.status(401).json({
          success: false,
          valid: false,
          error_message: 'Token expired'
        });
      }

      return res.status(200).json({
        success: true,
        valid: true,
        channelName,
        uid: userId,
        role: userRole
      });
    } catch (error) {
      console.error('Verify Agora token error:', error);
      return res.status(500).json({
        success: false,
        error_message: 'Failed to verify Agora token: ' + error.message
      });
    }
  });
});


// ========== Agora Token Generation ==========
exports.generateToken = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          error_message: 'Method not allowed'
        });
      }



      const { channelName, uid, userRole } = req.body;

      // Validate input
      if (!channelName) {
        return res.status(400).json({
          success: false,
          error_message: 'channelName is required'
        });
      }

      // Get Agora credentials from environment variables
      const appId = '225a62f4b5aa4e94ab46f91d0a0257e1';
      const appCertificate = '64ba1b2a26694545aac2f5f9ed86ac09';

      if (!appId || !appCertificate) {
        return res.status(500).json({
          success: false,
          error_message: 'Agora credentials not configured. Please set AGORA_APP_ID and AGORA_APP_CERTIFICATE environment variables.'
        });
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

      return res.status(200).json({
        success: true,
        token: token,
        appId: appId,
        channelName: channelName,
        uid: userId,
        role: userRole,
        expireTime: privilegeTs
      });

    } catch (error) {
      console.error('Generate Agora token error:', error);
      return res.status(500).json({
        success: false,
        error_message: 'Failed to generate Agora token: ' + error.message
      });
    }
  });
});

// ========== FCM Push Notification ==========
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          error_message: 'Method not allowed'
        });
      }

      // Verify authentication via JWT token
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          success: false,
          error_message: 'Authentication required'
        });
      }

      const { fcmToken, title, body, data: customData } = req.body;

      // Validate input
      if (!fcmToken || !title || !body) {
        return res.status(400).json({
          success: false,
          error_message: 'fcmToken, title, and body are required'
        });
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

      return res.status(200).json({
        success: true,
        messageId: response,
        response: response
      });

    } catch (error) {
      console.error('Error sending notification:', error);
      return res.status(500).json({
        success: false,
        error_message: 'Failed to send notification: ' + error.message
      });
    }
  });
});

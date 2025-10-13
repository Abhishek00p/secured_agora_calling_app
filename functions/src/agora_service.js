const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const cors = require('cors')({ origin: true });

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}


const AGORA_APP_ID = "225a62f4b5aa4e94ab46f91d0a0257e1";
const AGORA_CUSTOMER_ID = "e50e9e7e7a03423d882afc7cdee41ede";
const AGORA_CUSTOMER_CERT = "c6b70edc1d724e289608a59d9c64ea2c";

const BASE_URL = `https://api.agora.io/v1/apps/${AGORA_APP_ID}/cloud_recording`;
const AUTH_HEADER =
  "Basic " + Buffer.from(`${AGORA_CUSTOMER_ID}:${AGORA_CUSTOMER_CERT}`).toString("base64");

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


const GCloudAccessKey ="agora-recording@secure-calling-2025.iam.gserviceaccount.com";
const GCloudSecretKey ="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCK0J3OOjM8rW1U\nmlnpFH9QNMO2kvapNzjNT08XJKodMUtedM8/oGtvwCirJbCIxzQppJVkuc1OiS4H\nBvaQzFQ3DlUV1GMGOSfoRjsbxK8HqNiVAH/j9V90Yoqg1cGkmo79+hRU+6Q0eue9\nxmy5AwL64nDYdeBhJytBxUlKc2JZTn25huDxFT2oKdm/BX2zbO9jTzPaGTGj1GXO\nN2hG7PqdPKOMIVuoeKOd3fxWl6j3n6VcWM00LdXkHPxMVhx0HzH7/opGu/HqnOcX\npHWdXpZXrC3Xigq62lofqJKJ1feBFPtD82ZtqFXBZBSlSHmREtDu3sjdTZ7pClAi\nPbgHKjG3AgMBAAECggEAAwax1TIxaSdSUYlWrQoC2oGqXWHbAB/39e9xxtkVEkzZ\nGuAkbBUrTATeF7Kn8UHMEjchzWlvH3RGU7Kw3MHV+VtJIVz/cAr+VgYN7NJYit8a\nvAJsrbbTYJfZwNBxuvMzODf9VuFWsfdjjO1B9BvFZijzxjkPoRHEoIrt+/8DvygH\nXr1fEzpjMyZDMd28WOCbrTuoAxQ7R9pQQTJHNvErdvh71NItojKwe+FNXY3zVHXy\njMScTdeVGIuYUkbaSLAaR1h1BE/aYOgVAiv56dJCKz/vwR/wJU6ppWyL4+89ps3A\nw1jIEGIQ4aYhMUoaA4BQOuPrOGnctYE7mE6vKdeKQQKBgQDA85bnVwJ0b1KxAiNk\n9Sei1fOwR/emNAXsFutPMFooBeAX9xr2PiDV8ePqvJkRyVfB+9rgArgQprC7U89M\nvFHsJeOxn/YYD1kxYC8+CfNQF/Va7XUDEQwrIHICGLj+wjATsWaR+9Jjfas643QA\nvr2pDi1u8Qu8NpGdUtQUJazB9wKBgQC4LH6spHkF+gZ92FQlEZll8/zzVuKRmn07\nbg8Ve6LSkOuNMaXcKjDn5FCSEPOpwphpWZUeMMgUqsxfveJmOaQRBbCPqFG5QJUF\nUYFHYVwwWeRV+fWNeD3b+8GXJZBMASM7DeRuUPM7Ob1SoZPygT9A/6WhdxeYF0XY\nnF3tQH4eQQKBgQCZVDjzp1oFCr3MeaWEwaf4p0paKCZtBeQ640+kgwjxyxF0GeJs\nEZzoRqtWSv7ceoJpXWlmH+MDIGNKyWPvV6tGHCnfaf0Wy4OWUBfale+rEw7fbdlR\nUYe48bSHY/wGPmwUCiI3GcTrWN7sEfmJ6gkvQVvrUFOCAl8ehMaRKAsrqwKBgGBN\nA7+KEK4LWjGbWAQ5+5fPyEgE+ltgCHN2zPRSvYSUulYNy8gfV4spWufFbWMqmT8c\n1FgA8d28oTi+tQ72vM8ZxoSXYoQXPNSXFZ4ZTncJydca6EacxNut/D/oKFdVkPJk\nBTmZolUpj9ERI6b95fE6u4R+HRwtrxvgR0yzGD8BAoGAZu6Jp2QE0U34WrbrpmlX\nm/T4tuiql7KIWqT7/XvDxyNE5IDW2c1Fl2S7db+IhxhizH3rlo0Wia9sx5bUdIzA\nFsYABH/N0nVrzuFyFdcWYO8S6/SWbn125QBvMr7LRX+Nj8ociCI/vTLZ9PB1yPiC\nTD7KyWcagzOB8bnndi0XBaQ=\n-----END PRIVATE KEY-----\n";
const bucketName = "agora-recording-demo";
// RECORDING 


// ========== Acquire Resource ==========
exports.acquireRecordingResource = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, uid } = req.body;
      if (!cname || !uid)
        return res.status(400).json({ success: false, error_message: "Missing cname or uid" });

      const response = await axios.post(
        `${BASE_URL}/acquire`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );

      return res.status(200).json({
        success: true,
        resourceId: response.data.resourceId,
        data: response.data,
      });
    } catch (error) {
      console.error("Acquire Recording Error:", error);
      return res.status(500).json({
        success: false,
        error_message: "Failed to acquire recording resource: " + error.message,
      });
    }
  });
});

// ========== Start Both Recordings (Mix + Individual) ==========
exports.startDualCloudRecording = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, uid, resourceId,   } = req.body;
      if (!cname || !uid || !resourceId)
        return res.status(400).json({ success: false, error_message: "Missing parameters" });

      // Common storage config
      const storageConfig = {
        vendor: 6, // google cloud
        region: 0,
        bucketName,
        GCloudAccessKey,
        GCloudSecretKey,
        fileNamePrefix: ["agora", "recordings"],
      };

      // Mixed audio config
      const mixBody = {
        cname,
        uid,
        clientRequest: {
          recordingConfig: {
            channelType: 1,
            streamTypes: 1,
            audioProfile: 1,
            maxIdleTime: 60,
          },
          storageConfig,
        },
      };

      // Individual audio config
      const individualBody = {
        cname,
        uid,
        clientRequest: {
          recordingConfig: {
            channelType: 1,
            streamTypes: 1,
            audioProfile: 1,
            maxIdleTime: 60,
          },
          storageConfig,
        },
      };

      // Start MIX recording
      const mixResp = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/mode/mix/start`,
        mixBody,
        { headers: { Authorization: AUTH_HEADER } }
      );

      // Start INDIVIDUAL recording
      const indivResp = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/mode/individual/start`,
        individualBody,
        { headers: { Authorization: AUTH_HEADER } }
      );

      return res.status(200).json({
        success: true,
        mixSid: mixResp.data.sid,
        individualSid: indivResp.data.sid,
        mixResponse: mixResp.data,
        individualResponse: indivResp.data,
      });
    } catch (error) {
      console.error("Start Dual Recording Error:", error);
      return res.status(500).json({
        success: false,
        error_message: "Failed to start dual recording: " + error.message,
      });
    }
  });
});

// ========== Stop Both Recordings ==========
exports.stopDualCloudRecording = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, uid, resourceId, mixSid, individualSid } = req.body;
      if (!cname || !uid || !resourceId)
        return res.status(400).json({ success: false, error_message: "Missing parameters" });

      // Stop MIX recording
      const stopMix = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/sid/${mixSid}/mode/mix/stop`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );

      // Stop INDIVIDUAL recording
      const stopIndiv = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/sid/${individualSid}/mode/individual/stop`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );

      return res.status(200).json({
        success: true,
        mixResult: stopMix.data,
        individualResult: stopIndiv.data,
      });
    } catch (error) {
      console.error("Stop Dual Recording Error:", error);
      return res.status(500).json({
        success: false,
        error_message: "Failed to stop dual recording: " + error.message,
      });
    }
  });
});
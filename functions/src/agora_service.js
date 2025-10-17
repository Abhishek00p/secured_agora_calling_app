const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const cors = require('cors')({ origin: true });
const axios = require("axios");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();


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

      if (!channelName || !uid) {
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

      const token = tokens[uid]['token'];
      const expireTime = tokens[uid]['expiry_time'];

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
          error_message: "{msg : 'Invalid token',\n fetchedToken: '" + token + "',\n ExpectedExpiryTime: '" + expireTime + "',currExpiryTime: '" + privilegeTs + "',\n expectedToken: '" + expectedToken + "'}"
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


const GCloudAccessKey = "agora-recording@secure-calling-2025.iam.gserviceaccount.com";
const GCloudSecretKey = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCK0J3OOjM8rW1U\nmlnpFH9QNMO2kvapNzjNT08XJKodMUtedM8/oGtvwCirJbCIxzQppJVkuc1OiS4H\nBvaQzFQ3DlUV1GMGOSfoRjsbxK8HqNiVAH/j9V90Yoqg1cGkmo79+hRU+6Q0eue9\nxmy5AwL64nDYdeBhJytBxUlKc2JZTn25huDxFT2oKdm/BX2zbO9jTzPaGTGj1GXO\nN2hG7PqdPKOMIVuoeKOd3fxWl6j3n6VcWM00LdXkHPxMVhx0HzH7/opGu/HqnOcX\npHWdXpZXrC3Xigq62lofqJKJ1feBFPtD82ZtqFXBZBSlSHmREtDu3sjdTZ7pClAi\nPbgHKjG3AgMBAAECggEAAwax1TIxaSdSUYlWrQoC2oGqXWHbAB/39e9xxtkVEkzZ\nGuAkbBUrTATeF7Kn8UHMEjchzWlvH3RGU7Kw3MHV+VtJIVz/cAr+VgYN7NJYit8a\nvAJsrbbTYJfZwNBxuvMzODf9VuFWsfdjjO1B9BvFZijzxjkPoRHEoIrt+/8DvygH\nXr1fEzpjMyZDMd28WOCbrTuoAxQ7R9pQQTJHNvErdvh71NItojKwe+FNXY3zVHXy\njMScTdeVGIuYUkbaSLAaR1h1BE/aYOgVAiv56dJCKz/vwR/wJU6ppWyL4+89ps3A\nw1jIEGIQ4aYhMUoaA4BQOuPrOGnctYE7mE6vKdeKQQKBgQDA85bnVwJ0b1KxAiNk\n9Sei1fOwR/emNAXsFutPMFooBeAX9xr2PiDV8ePqvJkRyVfB+9rgArgQprC7U89M\nvFHsJeOxn/YYD1kxYC8+CfNQF/Va7XUDEQwrIHICGLj+wjATsWaR+9Jjfas643QA\nvr2pDi1u8Qu8NpGdUtQUJazB9wKBgQC4LH6spHkF+gZ92FQlEZll8/zzVuKRmn07\nbg8Ve6LSkOuNMaXcKjDn5FCSEPOpwphpWZUeMMgUqsxfveJmOaQRBbCPqFG5QJUF\nUYFHYVwwWeRV+fWNeD3b+8GXJZBMASM7DeRuUPM7Ob1SoZPygT9A/6WhdxeYF0XY\nnF3tQH4eQQKBgQCZVDjzp1oFCr3MeaWEwaf4p0paKCZtBeQ640+kgwjxyxF0GeJs\nEZzoRqtWSv7ceoJpXWlmH+MDIGNKyWPvV6tGHCnfaf0Wy4OWUBfale+rEw7fbdlR\nUYe48bSHY/wGPmwUCiI3GcTrWN7sEfmJ6gkvQVvrUFOCAl8ehMaRKAsrqwKBgGBN\nA7+KEK4LWjGbWAQ5+5fPyEgE+ltgCHN2zPRSvYSUulYNy8gfV4spWufFbWMqmT8c\n1FgA8d28oTi+tQ72vM8ZxoSXYoQXPNSXFZ4ZTncJydca6EacxNut/D/oKFdVkPJk\nBTmZolUpj9ERI6b95fE6u4R+HRwtrxvgR0yzGD8BAoGAZu6Jp2QE0U34WrbrpmlX\nm/T4tuiql7KIWqT7/XvDxyNE5IDW2c1Fl2S7db+IhxhizH3rlo0Wia9sx5bUdIzA\nFsYABH/N0nVrzuFyFdcWYO8S6/SWbn125QBvMr7LRX+Nj8ociCI/vTLZ9PB1yPiC\nTD7KyWcagzOB8bnndi0XBaQ=\n-----END PRIVATE KEY-----\n";
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

const getDocId = (cname, type) => `${cname}_${type}`;

// ====== Start Recording ======
exports.startCloudRecording = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, uid, type } = req.body;

      if (!cname || !uid || !type)
        return res.status(400).json({ success: false, error_message: "Missing parameters" });

      if (!["mix", "individual"].includes(type))
        return res.status(400).json({ success: false, error_message: "Invalid type" });

      // 1️⃣ Acquire Resource
      const acquireRes = await axios.post(
        `${BASE_URL}/acquire`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );

      const resourceId = acquireRes.data.resourceId;

      // 2️⃣ Prepare Common Storage Config
      const storageConfig = {
        vendor: 6, // Google Cloud
        region: 0,
        bucket: bucketName,
        accessKey: GCloudAccessKey,
        secretKey: GCloudSecretKey,
        fileNamePrefix: ["agora", "recordings", type],
      };

      // 3️⃣ Build Start Body
      const startBody = {
        cname,
        uid,
        clientRequest: {
          recordingConfig: type === "mix"
            ? {
              channelType: 1,
              streamTypes: 0,
              audioProfile: 1, // ✅ valid in mix
              maxIdleTime: 160,
            }
            : {
              channelType: 1,
              streamTypes: 0,
              subscribeUidGroup: 0,
              maxIdleTime: 160, // ✅ simpler config for individual
            },
          storageConfig,
        },
      };

      // 4️⃣ Start Recording
      const startRes = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/mode/${type}/start`,
        startBody,
        { headers: { Authorization: AUTH_HEADER } }
      );
      const sid = startRes.data.sid;

      const startedAt = new Date().toISOString();

      // 🔹 Step 5: Store Recording Info in Firestore
      await db.collection("recordings").doc(getDocId(cname, type)).set({
        'channelName': cname,
        'uid': uid,
        'recordingType': type,
        'resourceId': resourceId,
        'sid': sid,
        'startedAt': startedAt,
        'status': "active",
      });

      // 5️⃣ Return
      return res.status(200).json({
        success: true,
        type,
        resourceId,
        sid: startRes.data.sid,
        response: startRes.data,
      });
    } catch (error) {
      console.error("Start Recording Error:", error);
      const errMsg = error.response?.data?.message || error.message;
      return res.status(500).json({
        success: false,
        error_message: "Failed to start recording: " + errMsg,
      });
    }
  });
});

// ====== Stop Recording ======
exports.stopCloudRecording = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, type } = req.body;
      if (!cname || !type)
        return res.status(400).json({ success: false, error_message: "Missing parameters" });

      const docRef = db.collection("recordings").doc(getDocId(cname, type));
      const docSnap = await docRef.get();

      if (!docSnap.exists)
        return res.status(404).json({ success: false, error_message: "No active recording found" });

      const data = docSnap.data();
      if (data.status === "stopped")
        return res.status(400).json({ success: false, error_message: "Recording already stopped" });

      const { uid, resourceId, sid } = data;

      // Stop the recording
      const stopRes = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/stop`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );
      // 🔹 Update Firestore
      await docRef.update({
        status: "stopped",
        stoppedAt: new Date().toISOString(),
        stopResponse: stopRes.data,
      });
      return res.status(200).json({
        success: true,
        type,
        result: stopRes.data,
      });
    } catch (error) {
      console.error("Stop Recording Error:", error);
      const errMsg = error.response?.data?.message || error.message;
     if(errMsg.includes('404')){
           return res.status(200).json({
        success: true,
        error_message: 'Recording already stopped or not found',
      });
     }
      return res.status(500).json({
        success: false,
        error_message: "Failed to stop recording: " + errMsg,
      });
    }
  });
});



/**
 * Cloud Function: queryCloudRecordingStatus
 * -----------------------------------------
 * Request body: { cname: string, type: "mix" | "individual" }
 * Uses Firestore data (sid, resourceId, etc.)
 * Queries Agora REST API to get current recording status
 * Updates Firestore document with latest info
 */
exports.queryCloudRecordingStatus = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ success: false, error_message: "Method not allowed" });
      }

      const { cname, type } = req.body;
      if (!cname || !type) {
        return res.status(400).json({ success: false, error_message: "Missing cname or type" });
      }

      // 🔹 Fetch recording info from Firestore
      const docRef = db.collection("recordings").doc(getDocId(cname, type));
      const docSnap = await docRef.get();

      if (!docSnap.exists) {
        return res.status(404).json({ success: false, error_message: "Recording not found in Firestore" });
      }

      const data = docSnap.data();
      const recordInfo = data;
      if (!recordInfo || !recordInfo.resourceId || !recordInfo.sid) {
        return res.status(400).json({ success: false, error_message: `Missing ${type} recording details` });
      }

      const { resourceId, sid } = recordInfo;
      const mode = type; // mode same as type ("mix" or "individual")

      // 🔹 Agora Query API
      const url = `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${mode}/query`;
      const response = await axios.get(url, {
        headers: { Authorization: AUTH_HEADER },
      });

      const agoraData = response.data;
      const currentStatus = agoraData?.serverResponse?.status || "unknown";

      // 🔹 Update Firestore with current status + timestamp
      await docRef.update({
        [`lastQueriedAt`]: admin.firestore.Timestamp.now(),
        [`status`]: currentStatus,
        [`agoraResponse`]: agoraData,
      });

      return res.status(200).json({
        success: true,
        cname,
        type,
        currentStatus,
        agoraResponse: agoraData,
      });
    } catch (error) {
      console.error("Query Recording Status Error:", error.response?.data || error.message);
      return res.status(500).json({
        success: false,
        error_message: error.response?.data || error.message,
      });
    }
  });
});
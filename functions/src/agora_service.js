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


const GCloudAccessKey = "GOOG1EXNBQ3V4QM63QPGH3WZZLEI4TB7LUOVRQLVH7A5H2T6XXMJXJX2D53IV";
const GCloudSecretKey = "1wokdU7u/n0UycF5QemfYpM+iRUiupVmLAwK8SZl";
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
      console.log('Acquiring recording resource for:', { cname, uid, type });
      const acquireRes = await axios.post(
        `${BASE_URL}/acquire`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );

      console.log('Acquire response:', acquireRes.data);
      
      // Validate acquire response
      if (!acquireRes.data || !acquireRes.data.resourceId) {
        console.error('Failed to acquire recording resource:', acquireRes.data);
        return res.status(500).json({
          success: false,
          error_message: 'Failed to acquire recording resource'
        });
      }

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
      
      console.log('Storage config:', {
        vendor: storageConfig.vendor,
        region: storageConfig.region,
        bucket: storageConfig.bucket,
        fileNamePrefix: storageConfig.fileNamePrefix
      });
      
      // Validate storage configuration
      if (!GCloudAccessKey || !GCloudSecretKey || !bucketName) {
        console.error('Invalid Google Cloud Storage configuration');
        return res.status(500).json({
          success: false,
          error_message: 'Google Cloud Storage configuration is invalid'
        });
      }

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
      console.log('Starting recording with config:', startBody);
      const startRes = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/mode/${type}/start`,
        startBody,
        { headers: { Authorization: AUTH_HEADER } }
      );
      
      console.log('Start recording response:', startRes.data);
      
      // Validate start response
      if (!startRes.data || !startRes.data.sid) {
        console.error('Failed to start recording:', startRes.data);
        return res.status(500).json({
          success: false,
          error_message: 'Failed to start recording - no session ID returned'
        });
      }
      
      const sid = startRes.data.sid;

      const startedAt = new Date().toISOString();

      // 🔹 Step 5: Store Recording Info in Firestore
      const recordingData = {
        'channelName': cname,
        'uid': uid,
        'recordingType': type,
        'resourceId': resourceId,
        'sid': sid,
        'startedAt': startedAt,
        'status': "active",
        'acquireResponse': acquireRes.data,
        'startResponse': startRes.data
      };
      
      console.log('Storing recording data in Firestore:', recordingData);
      await db.collection("recordings").doc(getDocId(cname, type)).set(recordingData);

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
      
      // Validate that we have the required data
      if (!uid || !resourceId || !sid) {
        console.error('Missing required recording data:', { uid, resourceId, sid });
        return res.status(400).json({
          success: false,
          error_message: 'Incomplete recording data - missing uid, resourceId, or sid'
        });
      }

      // Stop the recording
      console.log('Stopping recording:', { cname, type, resourceId, sid, uid });
      const stopRes = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/stop`,
        { cname, uid, clientRequest: {} },
        { headers: { Authorization: AUTH_HEADER } }
      );
      
      console.log('Stop recording response:', stopRes.data);
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
      
      // Check if it's a 404 error (recording not found)
      if (error.response?.status === 404) {
        console.log('Recording not found (404) - may have already stopped or never started');
       
        
        return res.status(200).json({
          success: true,
          message: 'Recording was not active or already stopped',
          
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
      console.log('Queried Agora recording status:', agoraData);
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
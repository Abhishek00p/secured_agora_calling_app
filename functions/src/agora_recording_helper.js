
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const axios = require("axios");
const { tokenGenerateHelper } = require('./token_helper');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();



require('dotenv').config();

const AGORA_APP_ID = process.env.AGORA_APP_ID;
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;
const AGORA_CUSTOMER_ID = process.env.AGORA_CUSTOMER_ID;
const AGORA_CUSTOMER_CERT = process.env.AGORA_CUSTOMER_CERT;
const cloudFlareAccessKey = process.env.CLOUDFLARE_ACCESS_KEY;
const cloudFlareSecretKey = process.env.CLOUDFLARE_SECRET_KEY;
const bucketName = process.env.BUCKET_NAME;
const CLOUDFLARE_ENDPOINT = process.env.CLOUDFLARE_ENDPOINT;

const BASE_URL = `https://api.agora.io/v1/apps/${AGORA_APP_ID}/cloud_recording`;
const AUTH_HEADER =
  "Basic " + Buffer.from(`${AGORA_CUSTOMER_ID}:${AGORA_CUSTOMER_CERT}`).toString("base64");



// RECORDING 

async function generateUniqueUserId() {
  const MAX_32BIT = 0x7fffffff; // 2^31 - 1

  // Fetch all existing user doc IDs
  const snapshot = await db.collection("users").get();
  const existingIds = snapshot.docs.map(doc => doc.id); // array of strings

  let userId;
  let tries = 0;

  do {
    // Safety: prevent infinite loop
    if (tries > 100) throw new Error("Unable to generate unique ID after 100 tries");

    // Generate 32-bit integer
    const timestampPart = Date.now() % 10000000; // last 7 digits of timestamp
    const randomPart = Math.floor(Math.random() * 1000); // 0-999
    userId = (timestampPart * 1000 + randomPart) % MAX_32BIT;

    tries++;
  } while (existingIds.includes(userId.toString())); // convert to string for comparison

  return userId;
}

const getDocId = (cname, type) => `${cname}_${type}`;

// ====== Start Recording ======
exports.startCloudRecording = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== "POST")
        return res.status(405).json({ success: false, error_message: "Method not allowed" });

      const { cname, type } = req.body;

      if (!cname || !type) {
        return res.status(400).json({
          success: false,
          error_message: "Missing parameters",
          error: {
            code: "MISSING_PARAMETERS",
            message: "One or more required parameters are missing.",
            missing_fields: [
              !cname ? "cname" : null,
              !type ? "type" : null,
            ].filter(Boolean),
            hint: "Please ensure cname, type, and token are provided in the request body.",
          },
        });
      }

      const newUid = await generateUniqueUserId();
      const { token, expireyTime } = await tokenGenerateHelper(cname, newUid, "0");
      const resultToken = token;

      console.log(`token of recorder user for joining channel , id :${newUid}`, resultToken);

      if (!["mix", "individual"].includes(type))
        return res.status(400).json({ success: false, error_message: "Invalid type" });

      // 1️⃣ Acquire Resource
      console.log('Acquiring recording resource for:', { cname, type });
      const acquireRes = await axios.post(
        `${BASE_URL}/acquire`,
        {
          cname, uid: newUid.toString(), clientRequest: {
          }
        },
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
        vendor: 11,
        region: 0,
        bucket: bucketName,
        accessKey: cloudFlareAccessKey,
        secretKey: cloudFlareSecretKey,
        fileNamePrefix: ["agora", "recordings", type],
        extensionParams: {
          "endpoint": "https://684d7d3ceda1fe3533f104f1cf8197c7.r2.cloudflarestorage.com"
        }
      };

      console.log('Storage config:', {
        vendor: storageConfig.vendor,
        region: storageConfig.region,
        bucket: storageConfig.bucket,
        fileNamePrefix: storageConfig.fileNamePrefix
      });

      // Validate storage configuration
      if (!cloudFlareAccessKey || !cloudFlareSecretKey || !bucketName) {
        console.error('Invalid Google Cloud Storage configuration');
        return res.status(500).json({
          success: false,
          error_message: 'Google Cloud Storage configuration is invalid'
        });
      }

      // 3️⃣ Build Start Body
      const startBody = {
        cname,
        uid: newUid.toString(),
        clientRequest: {
          token: resultToken,
          streamSubscribe: {
            audioUidList: {
              subscribeAudioUids: [
                "#allstream#"
              ]
            },
          },
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
          recordingFileConfig: {
            avFileType: [ "mp3"], // ✅ Include MP3 explicitly
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
        'recordingType': type,
        'resourceId': resourceId,
        'sid': sid,
        'startedAt': startedAt,
        'status': "active",
        'acquireResponse': acquireRes.data,
        'startResponse': startRes.data,
        "recorderUid": newUid,
        "m3u8Path": `${type}/${resourceId}_uid_${newUid}_e_audio.m3u8`,
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

      const { resourceId, sid, recorderUid } = data;

      // Validate that we have the required data
      if (!recorderUid || !resourceId || !sid) {
        console.error('Missing required recording data:', { recorderUid, resourceId, sid });
        return res.status(400).json({
          success: false,
          error_message: 'Incomplete recording data - missing recorderUid, resourceId, or sid'
        });
      }

      // Stop the recording
      console.log('Stopping recording:', { cname, type, resourceId, sid, recorderUid });
      const stopRes = await axios.post(
        `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/stop`,
        { cname, uid: recorderUid.toString(), clientRequest: {} },
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
      console.log("Stop Recording Error:", error);
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
      if (!resourceId || !sid) {
        return res.status(400).json({ success: false, error_message: `Missing ${cname} ${type} recording details` });
      }
      // 🔹 Agora Query API
      const url = `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${mode}/query`;
      const response = await axios.get(url, {
        headers: { Authorization: AUTH_HEADER },
      });
      console.log('\n\n ------------------------------\n Agora query response:', response.data);
      const agoraData = response.data;
      console.log('Queried Agora recording status:', agoraData);
      const currentStatus = agoraData?.serverResponse?.status || "unknown";

      // 🔹 Update Firestore with current status + timestamp
      await docRef.update({
        [`lastQueriedAt`]: Date.now(),
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
      console.error("Query Recording Status Error:", error.response || error.response?.data || error.message);
      return res.status(500).json({
        success: false,
        error_message: error.response?.data || error.message,
      });
    }
  });
});
exports.agoraWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const { eventType, errorCode, ...rest } = req.body;
    const timestamp = Date.now();

    const docId = `${timestamp}_${eventType}`;
    const data = {
      eventType: eventType || null,
      errorCode: errorCode || null,
      eventData: rest || {},
      receivedAt: admin.firestore.Timestamp.fromMillis(timestamp),
      readableTime: new Date(timestamp).toLocaleString("en-IN", {
        timeZone: "Asia/Kolkata",
      }),
    };

    // ✅ Immediately respond to Agora to avoid timeout
    res.status(200).send("OK");

    // Then save to Firestore (async, no need to await)
    db.collection('agora_webhook_error').doc(docId).set(data)
      .then(() => console.log("Webhook event stored:", docId))
      .catch((err) => console.error("Firestore write error:", err));

  } catch (e) {
    console.error("Webhook processing error:", e);
    res.status(500).send("Internal Server Error");
  }
});




exports.updateRecording = functions.https.onRequest(async (req, res) => {
  try {
    const { cname, type, uid, audioSubscribeUids = [] } = req.body;

    if (!cname || !type || !audioSubscribeUids) {
      return res.status(400).send({ error: "Missing required parameters." });
    }


    const docRef = db.collection("recordings").doc(getDocId(cname, type));
    const docSnap = await docRef.get();

    if (!docSnap.exists)
      return res.status(404).json({ success: false, error_message: "No active recording found" });

    const data = docSnap.data();
    if (data.status === "stopped")
      return res.status(400).json({ success: false, error_message: "Recording already stopped" });

    const { resourceId, sid } = data;

    // Prepare update request body
    const updateBody = {
      cname: cname,
      uid: uid.toString(),
      clientRequest: {
        streamSubscribe: {
          audioUidList: {
            subscribeAudioUids: audioSubscribeUids.length > 0 ? audioSubscribeUids : ["#allstream#"]
          },

        }
      }
    };

    // Call Agora update API
    const url = `https://api.agora.io/v1/apps/${AGORA_APP_ID}/cloud_recording/resourceid/${resourceId}/sid/${sid}/mode/${type}/update`;

    const response = await axios.post(url, updateBody, {
      headers: {
        Authorization: AUTH_HEADER,
        "Content-Type": "application/json"
      }
    });

    // Log response to Firestore (optional)
    const db = admin.firestore();
    const timestamp = Date.now();
    const docId = `updateRecording_${timestamp}`;
    await db.collection("agora_recording_updates").doc(docId).set({
      request: updateBody,
      response: response.data,
      createdAt: admin.firestore.Timestamp.fromMillis(timestamp),
    });

    res.status(200).send({ success: true, data: response.data });
  } catch (error) {
    console.error("Agora update error:", error.response?.data || error.message || error);
    res.status(500).send({ success: false, error: error.response?.data || error.message || error });
  }
});
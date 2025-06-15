require("dotenv").config();
const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");
const {RtcTokenBuilder, RtcRole} = require("agora-access-token");

// Initialize Firebase Admin SDK
admin.initializeApp();

const app = express();
app.use(cors({origin: true}));

// ========== Agora Token Generation ==========
app.get("/generateToken", (req, res) => {
  const {channelName, uid, userRole} = req.query;
  if (!channelName) {
    return res.status(400).json({error: "channelName required"});
  }

  const appId = process.env.APP_ID;
  const appCert = process.env.APP_CERTIFICATE;
  const userId = Number(uid) || 0;
  const role = userRole === "0" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
  const expireSec = 144000; // 40 hours
  const privilegeTs = Math.floor(Date.now() / 1000) + expireSec;
  const token = RtcTokenBuilder.buildTokenWithUid(
      appId, appCert, channelName, userId, role, privilegeTs,
  );

  return res.json({token});
});

// ========== FCM Push Notification ==========
app.post("/sendNotification", async (req, res) => {
  const {fcmToken, title, body, data} = req.body;

  if (!fcmToken || !title || !body) {
    return res.status(400).json({
      error: "fcmToken, title, and body are required",
    });
  }

  const message = {
    token: fcmToken,
    notification: {
      title,
      body,
    },
    data: data || {}, // Optional custom payload
  };

  try {
    const response = await admin.messaging().send(message);
    return res.json({success: true, response});
  } catch (error) {
    console.error("Error sending notification:", error);
    return res.status(500).json({success: false, error: error.message});
  }
});

exports.api = functions.https.onRequest(app);

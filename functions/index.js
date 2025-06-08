require('dotenv').config();
const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const app = express();
app.use(cors({ origin: true }));

app.get('/generateToken', (req, res) => {
  const { channelName, uid ,user_role } = req.query;
  if (!channelName) return res.status(400).json({ error: 'channelName required' });

  const appId = process.env.APP_ID;
  const appCert = process.env.APP_CERTIFICATE;
  const userId = Number(uid) || 0;
  const role = user_role === 0 ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
  const expireSec = 144000; // 40 hours in seconds
  const privilegeTs = Math.floor(Date.now() / 1000) + expireSec;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId, appCert, channelName, userId, role, privilegeTs
  );

  return res.json({ token });
});

exports.api = functions.https.onRequest(app);

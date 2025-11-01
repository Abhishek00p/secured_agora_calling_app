const { RtcTokenBuilder, RtcRole } = require('agora-token');
const axios = require('axios');
const { db } = require('../config/firebase');
const { AGORA_CONFIG } = require('../config/env');
const { logger } = require('../middlewares/logging.middleware');

const BASE_URL = `https://api.agora.io/v1/apps/${AGORA_CONFIG.appId}/cloud_recording`;
const AUTH_HEADER = "Basic " + Buffer.from(
  `${AGORA_CONFIG.customerId}:${AGORA_CONFIG.customerCert}`
).toString("base64");

/**
 * Generate Agora Token
 */
exports.generateToken = async (req, res) => {
  try {
    const { channelName, uid, role = 'publisher' } = req.body;

    if (!AGORA_CONFIG.appId || !AGORA_CONFIG.appCertificate) {
      return res.status(500).json({
        success: false,
        error_message: 'Agora credentials not configured'
      });
    }

    // Set token expiration time (1 hour)
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    // Build token
    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_CONFIG.appId,
      AGORA_CONFIG.appCertificate,
      channelName,
      uid,
      role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER,
      privilegeExpiredTs
    );

    // Store token in Firestore
    await db.collection('meetings').doc(channelName).set({
      token,
      uid,
      role,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(privilegeExpiredTs * 1000).toISOString()
    });

    res.status(200).json({
      success: true,
      data: { token }
    });
  } catch (error) {
    logger.error('Generate token error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to generate token'
    });
  }
};

/**
 * Verify Agora Token
 */
exports.verifyToken = async (req, res) => {
  try {
    const { channelName, uid } = req.body;

    const meetingDoc = await db.collection('meetings')
      .doc(channelName)
      .get();

    if (!meetingDoc.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'Meeting not found'
      });
    }

    const meetingData = meetingDoc.data();
    const expiresAt = new Date(meetingData.expiresAt);

    if (expiresAt < new Date()) {
      return res.status(401).json({
        success: false,
        error_message: 'Token expired'
      });
    }

    if (meetingData.uid !== uid) {
      return res.status(401).json({
        success: false,
        error_message: 'Invalid user ID'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        token: meetingData.token,
        role: meetingData.role
      }
    });
  } catch (error) {
    logger.error('Verify token error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to verify token'
    });
  }
};

/**
 * Helper function to generate document ID for recordings
 */
const getDocId = (cname, type) => `${cname}_${type}`;

/**
 * Start Cloud Recording
 */
exports.startCloudRecording = async (req, res) => {
  try {
    const { cname, uid, type = 'mix' } = req.body;

    // Acquire recording resource
    const acquireResponse = await axios.post(
      `${BASE_URL}/acquire`,
      {
        cname,
        uid: uid.toString(),
        clientRequest: { resourceExpiredHour: 24 }
      },
      { headers: { Authorization: AUTH_HEADER } }
    );

    const { resourceId } = acquireResponse.data;

    // Start recording
    const startResponse = await axios.post(
      `${BASE_URL}/resourceid/${resourceId}/mode/${type}/start`,
      {
        cname,
        uid: uid.toString(),
        clientRequest: {
          token: null,
          recordingConfig: {
            maxIdleTime: 30,
            streamTypes: 2,
            channelType: 1,
            videoStreamType: 0,
            transcodingConfig: {
              height: 640,
              width: 360,
              bitrate: 500,
              fps: 15,
              mixedVideoLayout: 1,
              backgroundColor: "#000000",
            },
          },
          recordingFileConfig: {
            avFileType: ["hls", "mp4"],
          },
        },
      },
      { headers: { Authorization: AUTH_HEADER } }
    );

    // Store recording info in Firestore
    await db.collection('recordings').doc(getDocId(cname, type)).set({
      cname,
      type,
      resourceId,
      sid: startResponse.data.sid,
      recorderUid: uid,
      status: 'started',
      startedAt: new Date().toISOString(),
      startResponse: startResponse.data
    });

    res.status(200).json({
      success: true,
      data: startResponse.data
    });
  } catch (error) {
    logger.error('Start recording error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to start recording'
    });
  }
};

/**
 * Stop Cloud Recording
 */
exports.stopCloudRecording = async (req, res) => {
  try {
    const { cname, type } = req.body;

    const docRef = db.collection('recordings').doc(getDocId(cname, type));
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'No active recording found'
      });
    }

    const data = docSnap.data();
    if (data.status === 'stopped') {
      return res.status(400).json({
        success: false,
        error_message: 'Recording already stopped'
      });
    }

    const { resourceId, sid, recorderUid } = data;

    // Stop recording
    const stopResponse = await axios.post(
      `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/stop`,
      {
        cname,
        uid: recorderUid.toString(),
        clientRequest: {}
      },
      { headers: { Authorization: AUTH_HEADER } }
    );

    // Update Firestore
    await docRef.update({
      status: 'stopped',
      stoppedAt: new Date().toISOString(),
      stopResponse: stopResponse.data
    });

    res.status(200).json({
      success: true,
      data: stopResponse.data
    });
  } catch (error) {
    logger.error('Stop recording error:', error);
    if (error.response?.status === 404) {
      return res.status(200).json({
        success: true,
        message: 'Recording was not active or already stopped'
      });
    }
    res.status(500).json({
      success: false,
      error_message: 'Failed to stop recording'
    });
  }
};

/**
 * Query Cloud Recording Status
 */
exports.queryRecordingStatus = async (req, res) => {
  try {
    const { cname, type } = req.body;

    const docRef = db.collection('recordings').doc(getDocId(cname, type));
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'Recording not found'
      });
    }

    const data = docSnap.data();
    const { resourceId, sid } = data;

    const response = await axios.get(
      `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/query`,
      { headers: { Authorization: AUTH_HEADER } }
    );

    // Update status in Firestore
    await docRef.update({
      queryResponse: response.data,
      lastQueried: new Date().toISOString()
    });

    res.status(200).json({
      success: true,
      data: response.data
    });
  } catch (error) {
    logger.error('Query recording status error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to query recording status'
    });
  }
};

/**
 * Update Recording
 */
exports.updateRecording = async (req, res) => {
  try {
    const { cname, type, uid, audioSubscribeUids = [] } = req.body;

    const docRef = db.collection('recordings').doc(getDocId(cname, type));
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'No active recording found'
      });
    }

    const data = docSnap.data();
    if (data.status === 'stopped') {
      return res.status(400).json({
        success: false,
        error_message: 'Recording already stopped'
      });
    }

    const { resourceId, sid } = data;

    const response = await axios.post(
      `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/${type}/update`,
      {
        cname,
        uid: uid.toString(),
        clientRequest: {
          streamSubscribe: {
            audioUidList: {
              subscribeAudioUids: audioSubscribeUids.length > 0 ? audioSubscribeUids : ['#allstream#']
            }
          }
        }
      },
      { headers: { Authorization: AUTH_HEADER } }
    );

    // Log update to Firestore
    await db.collection('agora_recording_updates').add({
      cname,
      type,
      request: {
        audioSubscribeUids
      },
      response: response.data,
      createdAt: new Date().toISOString()
    });

    res.status(200).json({
      success: true,
      data: response.data
    });
  } catch (error) {
    logger.error('Update recording error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to update recording'
    });
  }
};
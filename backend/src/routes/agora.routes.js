const express = require('express');
const router = express.Router();
const agoraController = require('../controllers/agora.controller');
const { verifyToken } = require('../middlewares/auth.middleware');
const { validateAgoraTokenRequest, validateRecordingRequest } = require('../middlewares/validation.middleware');

// Token management
router.post('/token', [verifyToken, validateAgoraTokenRequest], agoraController.generateToken);
router.post('/verify-token', validateAgoraTokenRequest, agoraController.verifyToken);

// Recording management
router.post('/recording/start', [verifyToken, validateRecordingRequest], agoraController.startCloudRecording);
router.post('/recording/stop', [verifyToken, validateRecordingRequest], agoraController.stopCloudRecording);
router.post('/recording/status', [verifyToken, validateRecordingRequest], agoraController.queryRecordingStatus);
router.post('/recording/update', [verifyToken, validateRecordingRequest], agoraController.updateRecording);

module.exports = router;
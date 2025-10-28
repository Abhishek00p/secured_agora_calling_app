const functions = require("firebase-functions");
const auth = require('./src/auth');
const authHttp = require('./src/auth_http');
const agora = require('./src/agora_recording_helper');
const tokenHelper = require('./src/token_helper');

// Export all authentication functions (HTTP versions)
exports.login = authHttp.login;
exports.createUser = authHttp.createUser;
exports.createMember = authHttp.createMember;
exports.resetPassword = authHttp.resetPassword;
exports.getUserCredentials = authHttp.getUserCredentials;
exports.getUsersForPasswordReset = authHttp.getUsersForPasswordReset;

// Export all Agora service functions
exports.generateToken = tokenHelper.generateToken;
exports.verifyToken = tokenHelper.verifyToken;
exports.sendNotification = tokenHelper.sendNotification;
exports.acquireRecordingResource = agora.acquireRecordingResource;
exports.startCloudRecording = agora.startCloudRecording;
exports.stopCloudRecording = agora.stopCloudRecording;
exports.queryCloudRecordingStatus = agora.queryCloudRecordingStatus;
exports.agoraWebhook = agora.agoraWebhook;
exports.updateRecording = agora.updateRecording;

const functions = require("firebase-functions");
const auth = require('./src/auth');
const authHttp = require('./src/auth_http');
const agora = require('./src/agora_service');

// Export all authentication functions (HTTP versions)
exports.login = authHttp.login;
exports.createUser = authHttp.createUser;
exports.createMember = authHttp.createMember;
exports.resetPassword = authHttp.resetPassword;
exports.getUserCredentials = authHttp.getUserCredentials;
exports.getUsersForPasswordReset = authHttp.getUsersForPasswordReset;

// Export all Agora service functions
exports.generateToken = agora.generateToken;
exports.verifyToken = agora.verifyToken;
exports.sendNotification = agora.sendNotification;

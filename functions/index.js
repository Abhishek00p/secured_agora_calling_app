const functions = require("firebase-functions");
const auth = require('./src/auth');
const agora = require('./src/agora_service');

// Export all authentication functions
exports.login = auth.login;
exports.createUser = auth.createUser;
exports.createMember = auth.createMember;
exports.resetPassword = auth.resetPassword;
exports.getUserCredentials = auth.getUserCredentials;
exports.getUsersForPasswordReset = auth.getUsersForPasswordReset;

// Export all Agora service functions
exports.generateToken = agora.generateToken;
exports.sendNotification = agora.sendNotification;

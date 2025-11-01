const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { verifyToken, isAdmin, isMember } = require('../middlewares/auth.middleware');
const {
  validateLoginRequest,
  validateCreateUserRequest
} = require('../middlewares/validation.middleware');

// Public routes
router.post('/login', validateLoginRequest, authController.login);

// Protected routes
router.post('/create-user', [verifyToken, isAdmin, validateCreateUserRequest], authController.createUser);
router.post('/reset-password', [verifyToken, isAdmin], authController.resetPassword);
router.get('/user-credentials/:userId', verifyToken, authController.getUserCredentials);
router.get('/users-for-reset/:currentUserId', [verifyToken, isAdmin], authController.getUsersForPasswordReset);

module.exports = router;
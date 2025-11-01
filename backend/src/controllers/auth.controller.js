const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { db } = require('../config/firebase');
const { JWT_SECRET } = require('../config/env');
const { logger } = require('../middlewares/logging.middleware');

/**
 * Helper function to generate JWT token
 */
const generateToken = (userId, role) => {
  return jwt.sign(
    { userId, role },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
};

/**
 * Helper function to hash password
 */
const hashPassword = async (password) => {
  const saltRounds = 10;
  return bcrypt.hash(password, saltRounds);
};

/**
 * Helper function to verify password
 */
const verifyPassword = async (password, hashedPassword) => {
  return bcrypt.compare(password, hashedPassword);
};

/**
 * User Login
 */
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    logger.info('Attempting login for:', { email });

    // Find user in Firestore
    const usersRef = db.collection('users');
    const userQuery = await usersRef.where('email', '==', email).get();

    if (userQuery.empty) {
      return res.status(404).json({
        success: false,
        error_message: 'User not found'
      });
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();

    // Check if hashedPassword exists
    if (!userData.hashedPassword) {
      return res.status(400).json({
        success: false,
        error_message: 'User password not properly configured'
      });
    }

    // Verify password
    const isPasswordValid = await verifyPassword(password, userData.hashedPassword);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        error_message: 'Invalid password'
      });
    }

    // Check if user is active
    if (userData.isActive === false) {
      return res.status(401).json({
        success: false,
        error_message: 'User account is inactive'
      });
    }

    // Generate token
    const token = generateToken(userDoc.id, userData.isAdmin ? 'admin' : (userData.isMember ? 'member' : 'user'));

    res.status(200).json({
      success: true,
      data: {
        token,
        user: {
          userId: userDoc.id,
          email: userData.email,
          name: userData.name,
          isAdmin: userData.isAdmin || false,
          isMember: userData.isMember || false,
          memberCode: userData.memberCode
        }
      }
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to login'
    });
  }
};

/**
 * Create User
 */
exports.createUser = async (req, res) => {
  try {
    const { email, password, name, isAdmin, isMember, memberCode } = req.body;

    // Check if user already exists
    const existingUser = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (!existingUser.empty) {
      return res.status(400).json({
        success: false,
        error_message: 'User already exists'
      });
    }

    // Hash password
    const hashedPassword = await hashPassword(password);

    // Create user document
    const userDoc = await db.collection('users').add({
      email,
      name,
      hashedPassword,
      isAdmin: isAdmin || false,
      isMember: isMember || false,
      memberCode: memberCode || null,
      isActive: true,
      createdAt: new Date().toISOString()
    });

    res.status(201).json({
      success: true,
      data: {
        userId: userDoc.id,
        email,
        name,
        isAdmin: isAdmin || false,
        isMember: isMember || false,
        memberCode
      }
    });
  } catch (error) {
    logger.error('Create user error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to create user'
    });
  }
};

/**
 * Reset Password
 */
exports.resetPassword = async (req, res) => {
  try {
    const { userId, newPassword } = req.body;

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'User not found'
      });
    }

    // Hash new password
    const hashedPassword = await hashPassword(newPassword);

    // Update password
    await userDoc.ref.update({
      hashedPassword,
      updatedAt: new Date().toISOString()
    });

    res.status(200).json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (error) {
    logger.error('Reset password error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to reset password'
    });
  }
};

/**
 * Get User Credentials
 */
exports.getUserCredentials = async (req, res) => {
  try {
    const { userId } = req.params;

    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'User not found'
      });
    }

    const userData = userDoc.data();

    res.status(200).json({
      success: true,
      data: {
        userId: userDoc.id,
        email: userData.email,
        name: userData.name,
        isAdmin: userData.isAdmin || false,
        isMember: userData.isMember || false,
        memberCode: userData.memberCode
      }
    });
  } catch (error) {
    logger.error('Get user credentials error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to get user credentials'
    });
  }
};

/**
 * Get Users for Password Reset
 */
exports.getUsersForPasswordReset = async (req, res) => {
  try {
    const { currentUserId } = req.params;

    // Get current user
    const currentUserDoc = await db.collection('users').doc(currentUserId).get();

    if (!currentUserDoc.exists) {
      return res.status(404).json({
        success: false,
        error_message: 'Current user not found'
      });
    }

    const currentUserData = currentUserDoc.data();
    let users = [];

    if (currentUserData.isAdmin) {
      // Admin can see all members
      const membersQuery = await db.collection('users')
        .where('isMember', '==', true)
        .get();

      users = membersQuery.docs.map(doc => ({
        userId: doc.id,
        name: doc.data().name || '',
        email: doc.data().email || '',
        memberCode: doc.data().memberCode || '',
        isMember: true
      }));
    } else if (currentUserData.isMember) {
      // Member can see users under their member code
      const usersQuery = await db.collection('users')
        .where('memberCode', '==', currentUserData.memberCode)
        .where('isMember', '==', false)
        .get();

      users = usersQuery.docs.map(doc => ({
        userId: doc.id,
        name: doc.data().name || '',
        email: doc.data().email || '',
        memberCode: doc.data().memberCode || '',
        isMember: false
      }));
    }

    res.status(200).json({
      success: true,
      data: users
    });
  } catch (error) {
    logger.error('Get users for password reset error:', error);
    res.status(500).json({
      success: false,
      error_message: 'Failed to get users'
    });
  }
};
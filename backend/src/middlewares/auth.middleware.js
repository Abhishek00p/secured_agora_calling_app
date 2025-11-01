const jwt = require('jsonwebtoken');
const { admin } = require('../config/firebase');
const { JWT_SECRET } = require('../config/env');

/**
 * Middleware to verify JWT token and attach user data to request
 */
const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        error_message: 'No token provided'
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Get user from Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decoded.userId)
      .get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        error_message: 'User not found'
      });
    }

    const userData = userDoc.data();
    
    // Check if user is active
    if (userData.isActive === false) {
      return res.status(401).json({
        success: false,
        error_message: 'User account is inactive'
      });
    }

    // Attach user data to request
    req.user = {
      id: userDoc.id,
      ...userData,
      role: decoded.role
    };

    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error_message: 'Invalid token'
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error_message: 'Token expired'
      });
    }
    return res.status(500).json({
      success: false,
      error_message: 'Failed to authenticate token'
    });
  }
};

/**
 * Middleware to check if user is an admin
 */
const isAdmin = (req, res, next) => {
  if (!req.user || !req.user.isAdmin) {
    return res.status(403).json({
      success: false,
      error_message: 'Access denied. Admin privileges required.'
    });
  }
  next();
};

/**
 * Middleware to check if user is a member
 */
const isMember = (req, res, next) => {
  if (!req.user || !req.user.isMember) {
    return res.status(403).json({
      success: false,
      error_message: 'Access denied. Member privileges required.'
    });
  }
  next();
};

module.exports = {
  verifyToken,
  isAdmin,
  isMember
};
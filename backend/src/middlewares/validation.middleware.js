/**
 * Validate email format
 */
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Middleware to validate login request
 */
const validateLoginRequest = (req, res, next) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      error_message: 'Email and password are required'
    });
  }

  if (!isValidEmail(email)) {
    return res.status(400).json({
      success: false,
      error_message: 'Invalid email format'
    });
  }

  next();
};

/**
 * Middleware to validate user creation request
 */
const validateCreateUserRequest = (req, res, next) => {
  const { email, password, name } = req.body;

  if (!email || !password || !name) {
    return res.status(400).json({
      success: false,
      error_message: 'Email, password, and name are required'
    });
  }

  if (!isValidEmail(email)) {
    return res.status(400).json({
      success: false,
      error_message: 'Invalid email format'
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      error_message: 'Password must be at least 6 characters long'
    });
  }

  next();
};

/**
 * Middleware to validate Agora token request
 */
const validateAgoraTokenRequest = (req, res, next) => {
  const { channelName, uid, role } = req.body;

  if (!channelName || !uid) {
    return res.status(400).json({
      success: false,
      error_message: 'Channel name and user ID are required'
    });
  }

  if (role && !['publisher', 'subscriber'].includes(role)) {
    return res.status(400).json({
      success: false,
      error_message: 'Invalid role specified'
    });
  }

  next();
};

/**
 * Middleware to validate recording request
 */
const validateRecordingRequest = (req, res, next) => {
  const { cname, uid, type } = req.body;

  if (!cname || !uid) {
    return res.status(400).json({
      success: false,
      error_message: 'Channel name and user ID are required'
    });
  }

  if (type && !['mix', 'individual'].includes(type)) {
    return res.status(400).json({
      success: false,
      error_message: 'Invalid recording type specified'
    });
  }

  next();
};

module.exports = {
  validateLoginRequest,
  validateCreateUserRequest,
  validateAgoraTokenRequest,
  validateRecordingRequest
};
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors')({ origin: true });
const crypto = require("crypto");

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JWT_SECRET = '8a5c8b2bf8eba4b002147ac398905830a682ba665873c37e88134c3881f663e4bd782884061551c04ce1e07a8b3bf01f814446bd472a0b91ae3d68daf0cadb51'

function verifyJWTToken(authHeader) {
  try {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new Error('No token provided');
    }

    const token = authHeader.substring(7).trim(); // Remove 'Bearer ' prefix
    console.log('Verifying token:', token);
    const decoded = jwt.verify(token, JWT_SECRET);
    return decoded;
  } catch (error) {
    console.log('Signing secret:', JWT_SECRET);

    if (error.name === 'TokenExpiredError') {
      throw new Error('Token has expired');
    } else if (error.name === 'JsonWebTokenError') {
      throw new Error('Token is invalid');
    } else {
      throw new Error('Token verification failed');
    }
  }
}

// Helper function to generate JWT token
function generateToken(userId, role) {
  return jwt.sign(
    { userId, role },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
}

// Helper function to hash password
async function hashPassword(password) {
  const saltRounds = 10;
  return bcrypt.hash(password, saltRounds);
}

// Helper function to verify password
async function verifyPassword(password, hashedPassword) {
  return bcrypt.compare(password, hashedPassword);
}

// Helper function to validate email format
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Helper function to generate unique user ID

async function generateUniqueUserId() {
  const MAX_32BIT = 0x7fffffff; // 2^31 - 1

  // Fetch all existing user doc IDs
  const snapshot = await db.collection("users").get();
  const existingIds = snapshot.docs.map(doc => doc.id); // array of strings

  let userId;
  let tries = 0;

  do {
    // Safety: prevent infinite loop
    if (tries > 100) throw new Error("Unable to generate unique ID after 100 tries");

    // Generate 32-bit integer
    const timestampPart = Date.now() % 10000000; // last 7 digits of timestamp
    const randomPart = Math.floor(Math.random() * 1000); // 0-999
    userId = (timestampPart * 1000 + randomPart) % MAX_32BIT;

    tries++;
  } while (existingIds.includes(userId.toString())); // convert to string for comparison

  return userId;
}


// 1. User Login - HTTP Function
exports.login = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      const { email, password } = req.body;
      console.log('Attempting login for:', email);

      // Validate input
      if (!email || !password) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Email and password are required'
        });
      }

      if (email.isEmpty) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Invalid userId'
        });
      }

      // Find user in Firestore
      const usersRef = db.collection('users');
      const userQuery = await usersRef.where('email', '==', email).get();

      if (userQuery.empty) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'User not found'
        });
      }

      const userDoc = userQuery.docs[0];
      const userData = userDoc.data();

      // Check if hashedPassword exists
      if (!userData.hashedPassword) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'User password not properly configured'
        });
      }

      // Verify password
      const isPasswordValid = await verifyPassword(password, userData.hashedPassword);
      if (!isPasswordValid) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Invalid password'
        });
      }

      // Check if user is active
      if (userData.isActive === false) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'User account is deactivated'
        });
      }

      // Generate JWT token
      const token = generateToken(userDoc.id, userData.isMember ? 'member' : 'user');

      // Update last login
      await userDoc.ref.update({
        lastLoginAt: Date.now(),
       
      });

      return res.status(200).json({
        success: true,
        data: {
          token: token,
          user: {
            userId: userData.userId,
            name: userData.name,
            email: userData.email,
            isMember: userData.isMember,
            memberCode: userData.memberCode,
            subscription: userData.subscription,
            firebaseUserId: userData.firebaseUserId,
            createdAt: userData.createdAt,
            planExpiryDate: userData.planExpiryDate,
            temporaryPassword: userData.temporaryPassword,
            isActive: userData.isActive,
            isAdmin: userData.isAdmin,
          }
        },
        error_message: null
      });

    } catch (error) {
      console.error('Login error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Login failed: ' + error.message
      });
    }
  });
});

// 2. Create User (by Member) - HTTP Function
exports.createUser = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      const authHeader = req.headers.authorization;
      if (!authHeader) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Authorization header required'
        });
      }

      let decodedToken;
      try {
        decodedToken = verifyJWTToken(authHeader);
      } catch (error) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: error.message
        });
      }

      const { name, email, password, memberCode } = req.body;
      const currentUserId = decodedToken.userId;

      // Validate input
      if (!name || !email || !password || !memberCode) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'All fields are required'
        });
      }

      if(email.length < 5){
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'User ID must be 5 characters or more'
        });
      }

     
      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Password must be at least 6 characters'
        });
      }

      // Check if current user is a member
      const currentUserRef = db.collection('users').doc(currentUserId);
      const currentUserDoc = await currentUserRef.get();

      if (!currentUserDoc.exists) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Current user not found'
        });
      }

      const currentUserData = currentUserDoc.data();
      if (!currentUserData.isMember) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'Only members can create users'
        });
      }

      // Verify member code matches
      if (currentUserData.memberCode !== memberCode) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'Invalid member code'
        });
      }

      // Check if email already exists
      const existingUserQuery = await db.collection('users')
        .where('email', '==', email)
        .get();

      if (!existingUserQuery.empty) {
        return res.status(409).json({
          success: false,
          data: null,
          error_message: 'User with this UserId already exists'
        });
      }
      const memberSubscription = currentUserData.subscription;

      // Hash password
      const hashedPassword = await hashPassword(password);

      // Generate unique user ID
      const userId = await generateUniqueUserId();

      // Create user document
      const userData = {
        name: name.trim(),
        email: email.trim().toLowerCase(),
        userId: userId,
        firebaseUserId: String(userId),
        memberCode: memberCode,
        hashedPassword: hashedPassword,
        temporaryPassword: password, // Store plain text for admin/member viewing
        passwordCreatedBy: currentUserData.email,
        passwordCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isMember: false,
        isActive: true,
        subscription: memberSubscription
      };

      await db.collection('users').doc(String(userId)).set(userData);

      // Update member's total users count
      await currentUserRef.update({
        totalUsers: admin.firestore.FieldValue.increment(1)
      });

      return res.status(201).json({
        success: true,
        data: {
          message: 'User created successfully',
          userId: userId
        },
        error_message: null
      });

    } catch (error) {
      console.error('Create user error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Failed to create user: ' + error.message
      });
    }
  });
});

// 3. Create Member (by Admin) - HTTP Function
exports.createMember = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      // Verify authentication
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Authentication required'
        });
      }

      let decodedToken;
      try {
        decodedToken = verifyJWTToken(authHeader);
      } catch (error) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: error.message
        });
      }

      const { name, email, password, memberCode, purchaseDate, planDays, maxParticipantsAllowed } = req.body;
      const currentUserId = decodedToken.userId;

      // Validate input
      if (!name || !email || !password || !memberCode || !purchaseDate || !planDays) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'All required fields must be provided'
        });
      }

      if(email.length < 5){
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'User ID must be 5 characters or more'
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Password must be at least 6 characters'
        });
      }

      // Check if current user is admin
      const currentUserRef = db.collection('users').doc(currentUserId);
      const currentUserDoc = await currentUserRef.get();

      if (!currentUserDoc.exists) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Current user not found'
        });
      }

      const currentUserData = currentUserDoc.data();
      if (!currentUserData.isAdmin) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'Only admins can create members'
        });
      }

      // Check if email already exists
      const existingUserQuery = await db.collection('users')
        .where('email', '==', email)
        .get();

      if (!existingUserQuery.empty) {
        return res.status(409).json({
          success: false,
          data: null,
          error_message: 'User with this User Id already exists'
        });
      }

      // Check if member code already exists
      const existingMemberQuery = await db.collection('members')
        .where('memberCode', '==', memberCode)
        .get();

      if (!existingMemberQuery.empty) {
        return res.status(409).json({
          success: false,
          data: null,
          error_message: 'Member code already exists'
        });
      }

      // Hash password
      const hashedPassword = await hashPassword(password);

      // Generate unique user ID
      const userId = await generateUniqueUserId();

      // Create user document
      const userData = {
        name: name.trim(),
        email: email.trim().toLowerCase(),
        userId: userId,
        firebaseUserId: String(userId),
        memberCode: memberCode,
        hashedPassword: hashedPassword,
        temporaryPassword: password, // Store plain text for admin viewing
        passwordCreatedBy: 'Admin',
        passwordCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isMember: true,
        isAdmin: false,
        isActive: true,
        subscription: {
          plan: planDays >= 365 ? 'Premium' : 'Gold',
          expiryDate: new Date(Date.now() + planDays * 24 * 60 * 60 * 1000)
        }
      };

      await db.collection('users').doc(String(userId)).set(userData);

      // Create member document
      const memberData = {
        id: userId,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        memberCode: memberCode,
        purchaseDate: new Date(purchaseDate),
        planDays: planDays,
        isActive: true,
        totalUsers: 0,
        maxParticipantsAllowed: maxParticipantsAllowed || 45
      };

      await db.collection('members').doc(String(userId)).set(memberData);

      return res.status(201).json({
        success: true,
        data: {
          message: 'Member created successfully',
          userId: userId,
          memberCode: memberCode
        },
        error_message: null
      });

    } catch (error) {
      console.error('Create member error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Failed to create member: ' + error.message
      });
    }
  });
});

// 4. Reset Password - HTTP Function
exports.resetPassword = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      // Verify authentication
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Authentication required'
        });
      }

      let decodedToken;
      try {
        decodedToken = verifyJWTToken(authHeader);
      } catch (error) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: error.message
        });
      }

      const { targetEmail, newPassword } = req.body;
      const currentUserId = decodedToken.userId;

      // Validate input
      if (!targetEmail || !newPassword) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Target email and new password are required'
        });
      }

      if (targetEmail.isEmpty) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'userId cannot be empty'
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Password must be at least 6 characters'
        });
      }

      // Get current user details
      const currentUserRef = db.collection('users').doc(currentUserId);
      const currentUserDoc = await currentUserRef.get();

      if (!currentUserDoc.exists) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Current user not found'
        });
      }

      const currentUserData = currentUserDoc.data();

      // Find target user
      const targetUserQuery = await db.collection('users')
        .where('email', '==', targetEmail)
        .get();

      if (targetUserQuery.empty) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Target user not found'
        });
      }

      const targetUserDoc = targetUserQuery.docs[0];
      const targetUserData = targetUserDoc.data();

      // Check permissions
      let canReset = false;

      if (currentUserData.isAdmin) {
        // Admin can reset member passwords
        canReset = targetUserData.isMember;
      } else if (currentUserData.isMember) {
        // Member can reset user passwords under their member code
        canReset = !targetUserData.isMember &&
          targetUserData.memberCode === currentUserData.memberCode;
      }

      if (!canReset) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'You do not have permission to reset this user\'s password'
        });
      }

      // Hash new password
      const hashedPassword = await hashPassword(newPassword);

      // Update user document
      await targetUserDoc.ref.update({
        hashedPassword: hashedPassword,
        temporaryPassword: newPassword, // Store plain text for admin/member viewing
        passwordResetBy: currentUserData.email,
        passwordResetAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return res.status(200).json({
        success: true,
        data: {
          message: 'Password reset successfully'
        },
        error_message: null
      });

    } catch (error) {
      console.error('Reset password error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Failed to reset password: ' + error.message
      });
    }
  });
});

// 5. Get User Credentials - HTTP Function
exports.getUserCredentials = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      // Verify authentication
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Authentication required'
        });
      }

      let decodedToken;
      try {
        decodedToken = verifyJWTToken(authHeader);
      } catch (error) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: error.message
        });
      }

      const { targetEmail } = req.body;
      const currentUserId = decodedToken.userId;

      // Validate input
      if (!targetEmail) {
        return res.status(400).json({
          success: false,
          data: null,
          error_message: 'Target email is required'
        });
      }

      // Get current user details
      const currentUserRef = db.collection('users').doc(currentUserId);
      const currentUserDoc = await currentUserRef.get();

      if (!currentUserDoc.exists) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Current user not found'
        });
      }

      const currentUserData = currentUserDoc.data();

      // Find target user
      const targetUserQuery = await db.collection('users')
        .where('email', '==', targetEmail)
        .get();

      if (targetUserQuery.empty) {
        return res.status(404).json({
          success: false,
          data: null,
          error_message: 'Target user not found'
        });
      }

      const targetUserDoc = targetUserQuery.docs[0];
      const targetUserData = targetUserDoc.data();

      // Check permissions
      let canView = false;

      if (currentUserData.isAdmin) {
        // Admin can view member credentials
        canView = targetUserData.isMember;
      } else if (currentUserData.isMember) {
        // Member can view user credentials under their member code
        canView = !targetUserData.isMember &&
          targetUserData.memberCode === currentUserData.memberCode;
      }

      if (!canView) {
        return res.status(403).json({
          success: false,
          data: null,
          error_message: 'You do not have permission to view this user\'s credentials'
        });
      }

      return res.status(200).json({
        success: true,
        data: {
          credentials: {
            email: targetUserData.email,
            password: targetUserData.temporaryPassword || 'No temporary password set',
            name: targetUserData.name,
            memberCode: targetUserData.memberCode
          }
        },
        error_message: null
      });

    } catch (error) {
      console.error('Get credentials error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Failed to get credentials: ' + error.message
      });
    }
  });
});

// 6. Get Users for Password Reset - HTTP Function
exports.getUsersForPasswordReset = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({
          success: false,
          data: null,
          error_message: 'Method not allowed'
        });
      }

      // Verify authentication
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: 'Authentication required'
        });
      }

      let decodedToken;
      try {
        decodedToken = verifyJWTToken(authHeader);
      } catch (error) {
        return res.status(401).json({
          success: false,
          data: null,
          error_message: error.message
        });
      }

      const currentUserId = decodedToken.userId;

      // Get current user details
      const currentUserRef = db.collection('users').doc(currentUserId);
      const currentUserDoc = await currentUserRef.get();

      if (!currentUserDoc.exists) {
        return res.status(404).json({
          success: false,
          data: null,
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

        users = membersQuery.docs.map(doc => {
          const data = doc.data();
          return {
            userId: doc.id,
            name: data.name || '',
            email: data.email || '',
            memberCode: data.memberCode || '',
            isMember: true
          };
        });
      } else if (currentUserData.isMember) {
        // Member can see users under their member code
        const usersQuery = await db.collection('users')
          .where('memberCode', '==', currentUserData.memberCode)
          .where('isMember', '==', false)
          .get();

        users = usersQuery.docs.map(doc => {
          const data = doc.data();
          return {
            userId: doc.id,
            name: data.name || '',
            email: data.email || '',
            memberCode: data.memberCode || '',
            isMember: false
          };
        });
      }

      return res.status(200).json({
        success: true,
        data: {
          users: users
        },
        error_message: null
      });

    } catch (error) {
      console.error('Get users error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error_message: 'Failed to get users: ' + error.message
      });
    }
  });
});

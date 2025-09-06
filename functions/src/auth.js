const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

function verifyJWTToken(authHeader) {
  try {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new Error('No token provided');
    }
    
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const decoded = jwt.verify(token, JWT_SECRET);
    return decoded;
  } catch (error) {
    throw new Error('Invalid token');
  }
}
// Helper function to generate JWT token
function generateToken(userId, role) {
  return jwt.sign(
    { userId, role, iat: Date.now() },
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
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 1000);
  return `${timestamp}${random}`;
}

// 1. User Login
exports.login = functions.https.onCall(async (data, context) => {
  try {
    const { email, password } = data;
    console.log('Attempting login for:', email, password);
    // Validate input
    if (!email || !password) {
      return {
        success: false,
        data: null,
        error_message: 'Email and password are required'
      };
    }

    if (!isValidEmail(email)) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid email format'
      };
    }

    // Find user in Firestore
    const usersRef = db.collection('users');
    const userQuery = await usersRef.where('email', '==', email).get();

    if (userQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'User not found'
      };
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();

    // Check if hashedPassword exists
    if (!userData.hashedPassword) {
      return {
        success: false,
        data: null,
        error_message: 'User password not properly configured'
      };
    }

    // Verify password
    const isPasswordValid = await verifyPassword(password, userData.hashedPassword);
    if (!isPasswordValid) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid password'
      };
    }

    // Check if user is active
    if (userData.isActive === false) {
      return {
        success: false,
        data: null,
        error_message: 'User account is deactivated'
      };
    }

    // Generate JWT token
    const token = generateToken(userDoc.id, userData.isMember ? 'member' : 'user');

    // Update last login
    await userDoc.ref.update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
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
    };

  } catch (error) {
    console.error('Login error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Login failed: ' + error.message
    };
  }
});

// 2. Create User (by Member)
exports.createUser = functions.https.onCall(async (data, context) => {
  try {

    const authHeader = context.rawRequest.headers.authorization;
    if (!authHeader) {
      return {
        success: false,
        data: null,
        error_message: 'Authorization header required'
      };
    }
    let decodedToken;
    try {
      decodedToken = verifyJWTToken(authHeader);
    } catch (error) {
      return {
        success: false,
        data: null,
        error_message: error.message
      };
    }
    const { name, email, password, memberCode } = data;
    const currentUserId = decodedToken.userId;

    // Validate input
    if (!name || !email || !password || !memberCode) {
      return {
        success: false,
        data: null,
        error_message: 'All fields are required'
      };
    }

    if (!isValidEmail(email)) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid email format'
      };
    }

    if (password.length < 6) {
      return {
        success: false,
        data: null,
        error_message: 'Password must be at least 6 characters'
      };
    }

    // Check if current user is a member
    const currentUserRef = db.collection('users').doc(String(currentUserId));
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      return {
        success: false,
        data: null,
        error_message: 'Current user not found'
      };
    }

    const currentUserData = currentUserDoc.data();
    if (!currentUserData.isMember) {
      return {
        success: false,
        data: null,
        error_message: 'Only members can create users'
      };
    }

    // Verify member code matches
    if (currentUserData.memberCode !== memberCode) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid member code'
      };
    }

    // Check if email already exists
    const existingUserQuery = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (!existingUserQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'User with this email already exists'
      };
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
      memberCode: memberCode,
      hashedPassword: hashedPassword,
      temporaryPassword: password, // Store plain text for admin/member viewing
      passwordCreatedBy: currentUserData.email,
      passwordCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isMember: false,
      isActive: true,
      subscription: null
    };

    await db.collection('users').doc(userId).set(userData);

    // Update member's total users count
    await currentUserRef.update({
      totalUsers: admin.firestore.FieldValue.increment(1)
    });

    return {
      success: true,
      data: {
        message: 'User created successfully',
        userId: userId
      },
      error_message: null
    };

  } catch (error) {
    console.error('Create user error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Failed to create user: ' + error.message
    };
  }
});

// 3. Create Member (by Admin)
exports.createMember = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    const authHeader = context.rawRequest.headers.authorization;
    if (!authHeader) {
      return {
        success: false,
        data: null,
        error_message: 'Authentication required'
      };
    }
    let decodedToken;
    try {
      decodedToken = verifyJWTToken(authHeader);
    } catch (error) {
      return {
        success: false,
        data: null,
        error_message: error.message
      };
    }

    const { name, email, password, memberCode, purchaseDate, planDays, maxParticipantsAllowed } = data;
    const currentUserId = decodedToken.userId;

    // Validate input
    if (!name || !email || !password || !memberCode || !purchaseDate || !planDays) {
      return {
        success: false,
        data: null,
        error_message: 'All required fields must be provided'
      };
    }

    if (!isValidEmail(email)) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid email format'
      };
    }

    if (password.length < 6) {
      return {
        success: false,
        data: null,
        error_message: 'Password must be at least 6 characters'
      };
    }

    // Check if current user is admin
    const currentUserRef = db.collection('users').doc(String(currentUserId));
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      return {
        success: false,
        data: null,
        error_message: 'Current user not found'
      };
    }

    const currentUserData = currentUserDoc.data();
    if (!currentUserData.isAdmin) {
      return {
        success: false,
        data: null,
        error_message: 'Only admins can create members'
      };
    }

    // Check if email already exists
    const existingUserQuery = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (!existingUserQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'User with this email already exists'
      };
    }

    // Check if member code already exists
    const existingMemberQuery = await db.collection('members')
      .where('memberCode', '==', memberCode)
      .get();

    if (!existingMemberQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'Member code already exists'
      };
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
    console.log('Creating user with userId data:', userData);
    await db.collection('users').doc(String(userId)).set(userData);
    console.log('User created with ID:', userId);
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
    console.log('Creating member with userId data:', memberData);
    await db.collection('members').doc(String(userId)).set(memberData);

    return {
      success: true,
      data: {
        message: 'Member created successfully',
        userId: userId,
        memberCode: memberCode
      },
      error_message: null
    };

  } catch (error) {
    console.error('Create member error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Failed to create member: ' + error.message
    };
  }
});

// 4. Reset Password
exports.resetPassword = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    const authHeader = context.rawRequest.headers.authorization;
    if (!authHeader) {
      return {
        success: false,
        data: null,
        error_message: 'Authentication required'
      };
    }
    let decodedToken;
    try {
      decodedToken = verifyJWTToken(authHeader);
    } catch (error) {
      return {
        success: false,
        data: null,
        error_message: error.message
      };
    }

    const { targetEmail, newPassword } = data;
    const currentUserId = decodedToken.userId;

    // Validate input
    if (!targetEmail || !newPassword) {
      return {
        success: false,
        data: null,
        error_message: 'Target email and new password are required'
      };
    }

    if (!isValidEmail(targetEmail)) {
      return {
        success: false,
        data: null,
        error_message: 'Invalid email format'
      };
    }

    if (newPassword.length < 6) {
      return {
        success: false,
        data: null,
        error_message: 'Password must be at least 6 characters'
      };
    }

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      return {
        success: false,
        data: null,
        error_message: 'Current user not found'
      };
    }

    const currentUserData = currentUserDoc.data();

    // Find target user
    const targetUserQuery = await db.collection('users')
      .where('email', '==', targetEmail)
      .get();

    if (targetUserQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'Target user not found'
      };
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
      return {
        success: false,
        data: null,
        error_message: 'You do not have permission to reset this user\'s password'
      };
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

    return {
      success: true,
      data: {
        message: 'Password reset successfully'
      },
      error_message: null
    };

  } catch (error) {
    console.error('Reset password error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Failed to reset password: ' + error.message
    };
  }
});

// 5. Get User Credentials
exports.getUserCredentials = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    const authHeader = context.rawRequest.headers.authorization;
    if (!authHeader) {
      return {
        success: false,
        data: null,
        error_message: 'Authentication required'
      };
    }
    let decodedToken;
    try {
      decodedToken = verifyJWTToken(authHeader);
    } catch (error) {
      return {
        success: false,
        data: null,
        error_message: error.message
      };
    }
    const { targetEmail } = data;
    const currentUserId = decodedToken.userId;

    // Validate input
    if (!targetEmail) {
      return {
        success: false,
        data: null,
        error_message: 'Target email is required'
      };
    }

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      return {
        success: false,
        data: null,
        error_message: 'Current user not found'
      };
    }

    const currentUserData = currentUserDoc.data();

    // Find target user
    const targetUserQuery = await db.collection('users')
      .where('email', '==', targetEmail)
      .get();

    if (targetUserQuery.empty) {
      return {
        success: false,
        data: null,
        error_message: 'Target user not found'
      };
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
      return {
        success: false,
        data: null,
        error_message: 'You do not have permission to view this user\'s credentials'
      };
    }

    return {
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
    };

  } catch (error) {
    console.error('Get credentials error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Failed to get credentials: ' + error.message
    };
  }
});

// 6. Get Users for Password Reset
exports.getUsersForPasswordReset = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    const authHeader = context.rawRequest.headers.authorization;
    if (!authHeader) {
      return {
        success: false,
        data: null,
        error_message: 'Authentication required'
      };
    }
    let decodedToken;
    try {
      decodedToken = verifyJWTToken(authHeader);
    } catch (error) {
      return {
        success: false,
        data: null,
        error_message: error.message
      };
    }

    const currentUserId = decodedToken.userId;

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      return {
        success: false,
        data: null,
        error_message: 'Current user not found'
      };
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

    return {
      success: true,
      data: {
        users: users
      },
      error_message: null
    };

  } catch (error) {
    console.error('Get users error:', error);
    return {
      success: false,
      data: null,
      error_message: 'Failed to get users: ' + error.message
    };
  }
});







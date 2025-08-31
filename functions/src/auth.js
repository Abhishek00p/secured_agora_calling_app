const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

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

    // Validate input
    if (!email || !password) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email and password are required'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    // Find user in Firestore
    const usersRef = db.collection('users');
    const userQuery = await usersRef.where('email', '==', email).get();

    if (userQuery.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'User not found'
      );
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();

    // Check if hashedPassword exists
    if (!userData.hashedPassword) {
      throw new functions.https.HttpsError(
        'internal',
        'User password not properly configured'
      );
    }

    // Verify password
    const isPasswordValid = await verifyPassword(password, userData.hashedPassword);
    if (!isPasswordValid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Invalid password'
      );
    }

    // Check if user is active
    if (userData.isActive === false) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'User account is deactivated'
      );
    }

    // Generate JWT token
    const token = generateToken(userDoc.id, userData.isMember ? 'member' : 'user');

    // Update last login
    await userDoc.ref.update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      token,
      user: {
        userId: userDoc.id,
        name: userData.name,
        email: userData.email,
        isMember: userData.isMember,
        memberCode: userData.memberCode,
        subscription: userData.subscription
      }
    };

  } catch (error) {
    console.error('Login error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Login failed: ' + error.message
    );
  }
});

// 2. Create User (by Member)
exports.createUser = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { name, email, password, memberCode } = data;
    const currentUserId = context.auth.uid;

    // Validate input
    if (!name || !email || !password || !memberCode) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'All fields are required'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    if (password.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Password must be at least 6 characters'
      );
    }

    // Check if current user is a member
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found'
      );
    }

    const currentUserData = currentUserDoc.data();
    if (!currentUserData.isMember) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only members can create users'
      );
    }

    // Verify member code matches
    if (currentUserData.memberCode !== memberCode) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid member code'
      );
    }

    // Check if email already exists
    const existingUserQuery = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (!existingUserQuery.empty) {
      throw new functions.https.HttpsError(
        'already-exists',
        'User with this email already exists'
      );
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
      message: 'User created successfully',
      userId: userId
    };

  } catch (error) {
    console.error('Create user error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create user: ' + error.message
    );
  }
});

// 3. Create Member (by Admin)
exports.createMember = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { name, email, password, memberCode, purchaseDate, planDays, maxParticipantsAllowed } = data;
    const currentUserId = context.auth.uid;

    // Validate input
    if (!name || !email || !password || !memberCode || !purchaseDate || !planDays) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'All required fields must be provided'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    if (password.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Password must be at least 6 characters'
      );
    }

    // Check if current user is admin
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found'
      );
    }

    const currentUserData = currentUserDoc.data();
    if (!currentUserData.isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can create members'
      );
    }

    // Check if email already exists
    const existingUserQuery = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (!existingUserQuery.empty) {
      throw new functions.https.HttpsError(
        'already-exists',
        'User with this email already exists'
      );
    }

    // Check if member code already exists
    const existingMemberQuery = await db.collection('members')
      .where('memberCode', '==', memberCode)
      .get();

    if (!existingMemberQuery.empty) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Member code already exists'
      );
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

    await db.collection('users').doc(userId).set(userData);

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

    await db.collection('members').doc(userId).set(memberData);

    return {
      success: true,
      message: 'Member created successfully',
      userId: userId,
      memberCode: memberCode
    };

  } catch (error) {
    console.error('Create member error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create member: ' + error.message
    );
  }
});

// 4. Reset Password
exports.resetPassword = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { targetEmail, newPassword } = data;
    const currentUserId = context.auth.uid;

    // Validate input
    if (!targetEmail || !newPassword) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Target email and new password are required'
      );
    }

    if (!isValidEmail(targetEmail)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    if (newPassword.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Password must be at least 6 characters'
      );
    }

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found'
      );
    }

    const currentUserData = currentUserDoc.data();

    // Find target user
    const targetUserQuery = await db.collection('users')
      .where('email', '==', targetEmail)
      .get();

    if (targetUserQuery.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'Target user not found'
      );
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
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not have permission to reset this user\'s password'
      );
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
      message: 'Password reset successfully'
    };

  } catch (error) {
    console.error('Reset password error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to reset password: ' + error.message
    );
  }
});

// 5. Get User Credentials
exports.getUserCredentials = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const { targetEmail } = data;
    const currentUserId = context.auth.uid;

    // Validate input
    if (!targetEmail) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Target email is required'
      );
    }

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found'
      );
    }

    const currentUserData = currentUserDoc.data();

    // Find target user
    const targetUserQuery = await db.collection('users')
      .where('email', '==', targetEmail)
      .get();

    if (targetUserQuery.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'Target user not found'
      );
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
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not have permission to view this user\'s credentials'
      );
    }

    return {
      success: true,
      credentials: {
        email: targetUserData.email,
        password: targetUserData.temporaryPassword || 'No temporary password set',
        name: targetUserData.name,
        memberCode: targetUserData.memberCode
      }
    };

  } catch (error) {
    console.error('Get credentials error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get credentials: ' + error.message
    );
  }
});

// 6. Get Users for Password Reset
exports.getUsersForPasswordReset = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const currentUserId = context.auth.uid;

    // Get current user details
    const currentUserRef = db.collection('users').doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();

    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found'
      );
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
      users: users
    };

  } catch (error) {
    console.error('Get users error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get users: ' + error.message
    );
  }
});







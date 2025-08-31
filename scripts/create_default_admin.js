const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');

// Initialize Firebase Admin (you'll need to set up service account)
// admin.initializeApp({
//   credential: admin.credential.applicationDefault(),
//   projectId: 'your-project-id'
// });

// Or use service account key file
admin.initializeApp({
  credential: admin.credential.cert(require('../path-to-your-service-account.json')),
  projectId: 'your-project-id'
});

const db = admin.firestore();

async function createDefaultAdmin() {
  try {
    // Hash the password
    const hashedPassword = await bcrypt.hash('Flutter@123', 10);
    
    // Generate unique user ID
    const userId = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
    
    // Create admin user data
    const adminUserData = {
      name: 'Flutter Developer',
      email: 'flutterdeveloper771@gmail.com',
      userId: userId,
      memberCode: 'ADMIN-001',
      hashedPassword: hashedPassword,
      temporaryPassword: 'Flutter@123',
      passwordCreatedBy: 'System',
      passwordCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isMember: true,
      isAdmin: true,
      isActive: true,
      subscription: {
        plan: 'Premium',
        expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString()
      }
    };

    // Create member data
    const memberData = {
      id: userId,
      name: 'Flutter Developer',
      email: 'flutterdeveloper771@gmail.com',
      memberCode: 'ADMIN-001',
      purchaseDate: new Date(),
      planDays: 365,
      isActive: true,
      totalUsers: 0,
      maxParticipantsAllowed: 100
    };

    // Save to Firestore
    await db.collection('users').doc(userId).set(adminUserData);
    await db.collection('members').doc(userId).set(memberData);

    console.log('✅ Default admin user created successfully!');
    console.log('📧 Email: flutterdeveloper771@gmail.com');
    console.log('🔑 Password: Flutter@123');
    console.log('🆔 User ID:', userId);
    console.log('🏷️ Member Code: ADMIN-001');
    
  } catch (error) {
    console.error('❌ Error creating admin user:', error);
  }
}

// Run the function
createDefaultAdmin();

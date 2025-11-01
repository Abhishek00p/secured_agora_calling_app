const dotenv = require('dotenv');

dotenv.config();

const requiredEnvVars = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_PRIVATE_KEY',
  'JWT_SECRET',
  'AGORA_APP_ID',
  'AGORA_APP_CERTIFICATE',
  'AGORA_CUSTOMER_ID',
  'AGORA_CUSTOMER_CERT',
];

function validateEnv() {
  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingVars.join(', ')}\n` +
      'Please check your .env file and ensure all required variables are set.'
    );
  }
}

module.exports = {
  validateEnv,
  PORT: process.env.PORT || 3000,
  NODE_ENV: process.env.NODE_ENV || 'development',
  FIREBASE_CONFIG: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  },
  JWT_SECRET: process.env.JWT_SECRET,
  AGORA_CONFIG: {
    appId: process.env.AGORA_APP_ID,
    appCertificate: process.env.AGORA_APP_CERTIFICATE,
    customerId: process.env.AGORA_CUSTOMER_ID,
    customerCert: process.env.AGORA_CUSTOMER_CERT,
  },
  STORAGE_CONFIG: {
    cloudflareAccessKey: process.env.CLOUDFLARE_ACCESS_KEY,
    cloudflareSecretKey: process.env.CLOUDFLARE_SECRET_KEY,
    cloudflareEndpoint: process.env.CLOUDFLARE_ENDPOINT,
    bucketName: process.env.BUCKET_NAME,
  },
};
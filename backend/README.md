# Secured Agora Calling App Backend

This is the Express.js backend for the Secured Agora Calling App, migrated from Firebase Cloud Functions.

## Prerequisites

- Node.js (v18 or later)
- npm (v8 or later)
- Firebase Admin SDK credentials
- Agora account and credentials

## Setup Instructions

1. Clone the repository and navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a .env file:
   ```bash
   cp .env.example .env
   ```

4. Configure your environment variables in the .env file:
   - Firebase configuration
   - JWT secret
   - Agora credentials
   - Cloud storage configuration

5. Start the development server:
   ```bash
   npm run dev
   ```

   For production:
   ```bash
   npm start
   ```

## Project Structure

```
/backend
├── src/
│   ├── routes/          # Express route definitions
│   ├── controllers/     # Route handlers and business logic
│   ├── services/        # External service integrations
│   ├── utils/           # Helper functions and utilities
│   ├── middlewares/     # Express middlewares
│   └── config/          # Configuration files
├── server.js           # Application entry point
├── package.json        # Project dependencies and scripts
└── .env               # Environment variables
```

## API Endpoints

### Authentication
- POST `/api/auth/login` - User login
- POST `/api/auth/create-user` - Create new user
- POST `/api/auth/reset-password` - Reset user password

### Agora Integration
- POST `/api/agora/token` - Generate Agora token
- POST `/api/agora/verify-token` - Verify Agora token
- POST `/api/agora/recording/start` - Start cloud recording
- POST `/api/agora/recording/stop` - Stop cloud recording
- POST `/api/agora/recording/status` - Get recording status

## Environment Variables

Required environment variables:

```env
PORT=3000
NODE_ENV=development

# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY=your-private-key

# JWT Configuration
JWT_SECRET=your-jwt-secret-key

# Agora Configuration
AGORA_APP_ID=your-agora-app-id
AGORA_APP_CERTIFICATE=your-agora-app-certificate
AGORA_CUSTOMER_ID=your-agora-customer-id
AGORA_CUSTOMER_CERT=your-agora-customer-cert

# Cloud Storage Configuration
CLOUDFLARE_ACCESS_KEY=your-cloudflare-access-key
CLOUDFLARE_SECRET_KEY=your-cloudflare-secret-key
CLOUDFLARE_ENDPOINT=your-cloudflare-endpoint
BUCKET_NAME=your-bucket-name
```

## Error Handling

The application uses a centralized error handling middleware that:
- Logs errors using Winston
- Returns appropriate HTTP status codes
- Provides detailed error messages in development
- Sanitizes error messages in production

## Logging

Winston is configured for logging:
- Console output for development
- File-based logging for production
- Separate error log file for errors
- JSON format with timestamps

## Security

- CORS enabled with appropriate configuration
- Request body parsing with size limits
- Environment variable validation
- Firebase Admin SDK for authentication
- JWT for session management

## Deployment on Render

Follow these steps to deploy the backend to Render:

1. **Prepare Your Repository**
   - Push your code to a GitHub repository
   - Make sure your code is in the main/master branch

2. **Create a Render Account**
   - Sign up at https://render.com
   - Connect your GitHub account

3. **Create a New Web Service**
   - Click "New +"
   - Select "Web Service"
   - Choose your repository
   - Select the branch to deploy

4. **Configure the Service**
   - Name: `secured-agora-calling-backend` (or your preferred name)
   - Environment: `Node`
   - Region: Choose the closest to your users
   - Branch: `main` (or your default branch)
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Instance Type: Choose based on your needs (Free tier is good for testing)

5. **Set Environment Variables**
   In the Render dashboard, add these environment variables:
   ```
   NODE_ENV=production
   PORT=3000
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_CLIENT_EMAIL=your-client-email
   FIREBASE_PRIVATE_KEY=your-private-key
   JWT_SECRET=your-jwt-secret
   AGORA_APP_ID=your-agora-app-id
   AGORA_APP_CERTIFICATE=your-agora-app-certificate
   AGORA_CUSTOMER_ID=your-agora-customer-id
   AGORA_CUSTOMER_CERT=your-agora-customer-cert
   CLOUDFLARE_ACCESS_KEY=your-cloudflare-access-key
   CLOUDFLARE_SECRET_KEY=your-cloudflare-secret-key
   CLOUDFLARE_ENDPOINT=your-cloudflare-endpoint
   BUCKET_NAME=your-bucket-name
   ```

   **Important Notes:**
   - For `FIREBASE_PRIVATE_KEY`, include the entire key including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
   - Make sure to properly escape newlines in the private key by replacing `\n` with actual newlines
   - The `JWT_SECRET` should be a long, random string. You can let Render auto-generate it

6. **Deploy**
   - Click "Create Web Service"
   - Render will automatically build and deploy your application
   - You can monitor the deployment in the dashboard

7. **Verify Deployment**
   - Once deployed, Render will provide you with a URL (e.g., `https://your-app-name.onrender.com`)
   - Test your endpoints using this URL
   - Check the logs in the Render dashboard for any issues

8. **Set Up Auto-Deploy**
   - By default, Render will automatically deploy when you push to your main branch
   - You can configure branch rules in the service settings

9. **Monitor Your Service**
   - Use the Render dashboard to:
     - Monitor logs
     - Check metrics
     - Set up alerts
     - Scale your service if needed

Remember to update your frontend application's API endpoint to point to your new Render URL once deployed.
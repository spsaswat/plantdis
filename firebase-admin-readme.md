# Firebase User Management Script

This script allows you to manage Firebase users without needing to run the Flutter app.

## Prerequisites

1. Node.js installed on your computer (download from https://nodejs.org/)
2. Firebase Admin SDK service account key

## Setup

1. **Install required packages:**

   ```bash
   npm install firebase-admin
   ```

2. **Get your service account key:**

   a. Go to the [Firebase Console](https://console.firebase.google.com/)
   b. Select your project "plantdis-e42a4"
   c. Go to Project Settings > Service accounts
   d. Click "Generate new private key"
   e. Save the JSON file as `serviceAccountKey.json` in the same directory as this script

   **IMPORTANT:** Keep this file secure! It has admin access to your Firebase project.

## Using the Script

Run the script with:

```bash
node add_firebase_user.js
```

The script provides a menu-driven interface that allows you to:

1. **Create new users** - Creates both a Firebase Authentication user and a Firestore document with user data
2. **List users** - Shows the 10 most recent users in your Firebase project
3. **Delete users** - Removes a user by email from both Authentication and Firestore

## Custom Service Account Key Path

If you want to store your service account key in a different location, you can specify the path when running the script:

```bash
node add_firebase_user.js path/to/your/serviceAccountKey.json
```

## Security Warning

This script grants administrative access to your Firebase project. Never share your service account key or this script with unauthorized persons. 
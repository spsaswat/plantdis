// Firebase Admin SDK script to add users
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const readline = require('readline');

// Read command line arguments
const args = process.argv.slice(2);
const serviceAccountPath = args[0] || './serviceAccountKey.json';

// Check if service account file exists
if (!fs.existsSync(serviceAccountPath)) {
  console.error(`Error: Service account key file not found at ${serviceAccountPath}`);
  console.log('\nTo use this script:');
  console.log('1. Go to Firebase console -> Project settings -> Service accounts');
  console.log('2. Click "Generate new private key"');
  console.log('3. Save the JSON file as "serviceAccountKey.json" in this directory');
  console.log('4. Run this script again');
  process.exit(1);
}

// Initialize Firebase Admin
try {
  const serviceAccount = require(serviceAccountPath);
  initializeApp({
    credential: cert(serviceAccount)
  });
  console.log('Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('Error initializing Firebase Admin SDK:', error);
  process.exit(1);
}

const auth = getAuth();
const db = getFirestore();

// Create command line interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Main menu
function showMenu() {
  console.log('\n--- Firebase User Management ---');
  console.log('1. Create new user');
  console.log('2. List all users (10 most recent)');
  console.log('3. Delete user');
  console.log('4. Exit');
  
  rl.question('\nSelect an option (1-4): ', async (answer) => {
    switch (answer) {
      case '1':
        await createUserFlow();
        break;
      case '2':
        await listUsers();
        break;
      case '3':
        await deleteUserFlow();
        break;
      case '4':
        console.log('Exiting...');
        rl.close();
        break;
      default:
        console.log('Invalid option, please try again');
        showMenu();
    }
  });
}

// Create user flow
async function createUserFlow() {
  rl.question('Email: ', (email) => {
    rl.question('Password: ', (password) => {
      rl.question('Display name (optional): ', (displayName) => {
        // Additional user data collection for Firestore
        rl.question('Education level (e.g., Undergraduate): ', (educationLevel) => {
          rl.question('Industrial area (optional): ', async (industrialArea) => {
            try {
              // Create the user in Firebase Auth
              const userRecord = await auth.createUser({
                email,
                password,
                displayName: displayName || null,
              });
              
              console.log('User created successfully:', userRecord.uid);
              
              // Add additional data to Firestore
              const userData = {
                name: displayName || '',
                email,
                educationLevel: educationLevel || 'not selected',
                industrialArea: industrialArea || 'not selected',
                results: [], // Initialize results as empty array
                images: [],   // Initialize images as empty array
                createdAt: new Date(),
              };
              
              await db.collection('users').doc(userRecord.uid).set(userData);
              console.log('User data added to Firestore');
              
              showMenu();
            } catch (error) {
              console.error('Error creating user:', error);
              showMenu();
            }
          });
        });
      });
    });
  });
}

// List users
async function listUsers() {
  try {
    const listUsersResult = await auth.listUsers(10);
    
    console.log('\n--- User List ---');
    listUsersResult.users.forEach((userRecord) => {
      console.log(`UID: ${userRecord.uid}, Email: ${userRecord.email}, Name: ${userRecord.displayName || 'N/A'}`);
    });
    
    showMenu();
  } catch (error) {
    console.error('Error listing users:', error);
    showMenu();
  }
}

// Delete user flow
async function deleteUserFlow() {
  rl.question('Enter user email to delete: ', async (email) => {
    try {
      // Find the user by email
      const userRecord = await auth.getUserByEmail(email);
      
      rl.question(`Are you sure you want to delete user ${email}? (yes/no): `, async (answer) => {
        if (answer.toLowerCase() === 'yes') {
          // Delete from Authentication
          await auth.deleteUser(userRecord.uid);
          
          // Delete from Firestore
          try {
            await db.collection('users').doc(userRecord.uid).delete();
            console.log('User data deleted from Firestore');
          } catch (error) {
            console.log('Note: No Firestore data found for this user or error deleting it');
          }
          
          console.log(`User ${email} deleted successfully`);
        } else {
          console.log('Delete operation cancelled');
        }
        showMenu();
      });
    } catch (error) {
      console.error('Error finding or deleting user:', error);
      showMenu();
    }
  });
}

// Start the application
showMenu(); 
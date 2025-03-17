// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCYDhg6Hvf63pbzskUjFzItWm-fgBcW1yc",
  authDomain: "plantdis-e42a4.firebaseapp.com",
  projectId: "plantdis-e42a4",
  storageBucket: "plantdis-e42a4.appspot.com",
  messagingSenderId: "748587653216",
  appId: "1:748587653216:web:d7992935d3ab9ea82b8b05",
  measurementId: "G-QNCFWRG3E8"
};

// Initialize Firebase - make sure this runs after Firebase scripts are loaded
document.addEventListener('DOMContentLoaded', function() {
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    console.log("Firebase initialized successfully");
  } else {
    console.error("Firebase SDK not loaded");
  }
}); 
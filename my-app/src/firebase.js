// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getDatabase } from "firebase/database";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyC1XrdfX1tiYZkdtgX_zMH3nVh9aKVCn30",
  authDomain: "emergency-73ada.firebaseapp.com",
  databaseURL: "https://emergency-73ada-default-rtdb.firebaseio.com",
  projectId: "emergency-73ada",
  storageBucket: "emergency-73ada.firebasestorage.app",
  messagingSenderId: "969690894666",
  appId: "1:969690894666:web:3028ab7d1f7d3fc9f4b1b3",
  measurementId: "G-DQN68V1PX9"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Analytics only if window is defined (avoids SSR issues)
let analytics;
if (typeof window !== 'undefined') {
  analytics = getAnalytics(app);
}

const database = getDatabase(app);

export { app, analytics, database }; 
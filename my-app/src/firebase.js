// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getDatabase } from "firebase/database";

// Your web app's Firebase configuration
// New Blaze Plan Project: resmeapp-1
const firebaseConfig = {
  apiKey: "AIzaSyC9DBabjSOisYBPmH-UGo1sOWX0xfdnkxs",
  authDomain: "resmeapp-1.firebaseapp.com",
  databaseURL: "https://resmeapp-1-default-rtdb.firebaseio.com",
  projectId: "resmeapp-1",
  storageBucket: "resmeapp-1.firebasestorage.app",
  messagingSenderId: "984771585091",
  appId: "1:984771585091:web:ece3054f2577f9910e20f6",
  measurementId: "G-6F0ZJHWY83"
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
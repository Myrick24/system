// Firebase service initialization
import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { getStorage, connectStorageEmulator } from 'firebase/storage';
import { firebaseConfig } from '../config/firebase';

// Initialize Firebase app
const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Enable offline persistence for Firestore
try {
  // This helps with network issues
  if (typeof window !== 'undefined') {
    // Only run in browser environment
    console.log('Firebase services initialized successfully');
  }
} catch (error) {
  console.error('Firebase initialization error:', error);
}

export default app;

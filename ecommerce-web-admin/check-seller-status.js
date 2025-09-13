// Simple script to check seller status in both collections
// Run this with: node check-seller-status.js <seller-email>

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs, doc, getDoc } = require('firebase/firestore');

// Firebase config
const firebaseConfig = {
  apiKey: "AIzaSyA9m8T0oO4iPvG_zU02QarC8Wqek0H8N14",
  authDomain: "e-commerce-app-5cda8.firebaseapp.com",
  projectId: "e-commerce-app-5cda8",
  storageBucket: "e-commerce-app-5cda8.firebasestorage.app",
  messagingSenderId: "630973639309",
  appId: "1:630973639309:web:967af659d31635e2fa50c4",
  measurementId: "G-DGHNCV3T0J"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkSellerStatus(email) {
  console.log(`\n=== Checking status for seller: ${email} ===\n`);
  
  try {
    // Check users collection
    console.log('1. Checking users collection...');
    const usersQuery = query(
      collection(db, 'users'),
      where('email', '==', email)
    );
    const usersSnapshot = await getDocs(usersQuery);
    
    if (usersSnapshot.empty) {
      console.log('❌ No user found with this email in users collection');
    } else {
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        console.log(`✅ User found in users collection:`);
        console.log(`   - Document ID: ${doc.id}`);
        console.log(`   - Name: ${userData.name}`);
        console.log(`   - Role: ${userData.role}`);
        console.log(`   - Status: ${userData.status}`);
      });
    }
    
    // Check sellers collection
    console.log('\n2. Checking sellers collection...');
    const sellersQuery = query(
      collection(db, 'sellers'),
      where('email', '==', email)
    );
    const sellersSnapshot = await getDocs(sellersQuery);
    
    if (sellersSnapshot.empty) {
      console.log('❌ No seller found with this email in sellers collection');
    } else {
      sellersSnapshot.forEach(doc => {
        const sellerData = doc.data();
        console.log(`✅ Seller found in sellers collection:`);
        console.log(`   - Document ID: ${doc.id}`);
        console.log(`   - Name: ${sellerData.name}`);
        console.log(`   - Status: ${sellerData.status}`);
        console.log(`   - Verified: ${sellerData.verified}`);
        console.log(`   - User ID: ${sellerData.userId}`);
      });
    }
    
    console.log('\n=== Summary ===');
    console.log('For the seller status to show as approved in the app:');
    console.log('1. Users collection should have status: "approved"');
    console.log('2. Sellers collection should have status: "approved"');
    console.log('\nIf sellers collection status is still "pending", that\'s the issue!');
    
  } catch (error) {
    console.error('Error checking seller status:', error);
  }
}

// Get email from command line arguments
const email = process.argv[2];
if (!email) {
  console.log('Usage: node check-seller-status.js <seller-email>');
  console.log('Example: node check-seller-status.js seller@example.com');
  process.exit(1);
}

checkSellerStatus(email);

// Script to fix seller statuses - updates sellers collection to match users collection
// This fixes the issue where admin web approved sellers but didn't update sellers collection

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs, updateDoc } = require('firebase/firestore');

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

async function fixSellerStatuses() {
  console.log('🔧 Starting seller status fix...\n');
  
  try {
    // Get all approved sellers from users collection
    console.log('1. Finding approved sellers in users collection...');
    const approvedUsersQuery = query(
      collection(db, 'users'),
      where('role', '==', 'seller'),
      where('status', '==', 'approved')
    );
    const approvedUsersSnapshot = await getDocs(approvedUsersQuery);
    
    console.log(`Found ${approvedUsersSnapshot.size} approved sellers in users collection\n`);
    
    let fixedCount = 0;
    let alreadyCorrectCount = 0;
    
    // For each approved user, check and update their seller document
    for (const userDoc of approvedUsersSnapshot.docs) {
      const userData = userDoc.data();
      const userEmail = userData.email;
      
      console.log(`Processing: ${userData.name} (${userEmail})`);
      
      // Find corresponding seller document
      const sellersQuery = query(
        collection(db, 'sellers'),
        where('email', '==', userEmail)
      );
      const sellersSnapshot = await getDocs(sellersQuery);
      
      if (sellersSnapshot.empty) {
        console.log(`  ⚠️  No seller document found for ${userEmail}`);
        continue;
      }
      
      const sellerDoc = sellersSnapshot.docs[0];
      const sellerData = sellerDoc.data();
      
      if (sellerData.status === 'approved') {
        console.log(`  ✅ Already approved in sellers collection`);
        alreadyCorrectCount++;
      } else {
        console.log(`  🔄 Updating seller status from "${sellerData.status}" to "approved"`);
        await updateDoc(sellerDoc.ref, {
          status: 'approved'
        });
        fixedCount++;
        console.log(`  ✅ Fixed!`);
      }
    }
    
    console.log('\n=== RESULTS ===');
    console.log(`✅ Fixed: ${fixedCount} sellers`);
    console.log(`✅ Already correct: ${alreadyCorrectCount} sellers`);
    console.log(`📱 App should now show approved status for all fixed sellers!`);
    
  } catch (error) {
    console.error('❌ Error fixing seller statuses:', error);
  }
}

// Also provide a function to fix a specific seller by email
async function fixSpecificSeller(email) {
  console.log(`🔧 Fixing specific seller: ${email}\n`);
  
  try {
    // Find user
    const usersQuery = query(
      collection(db, 'users'),
      where('email', '==', email)
    );
    const usersSnapshot = await getDocs(usersQuery);
    
    if (usersSnapshot.empty) {
      console.log('❌ No user found with this email');
      return;
    }
    
    const userData = usersSnapshot.docs[0].data();
    console.log(`User status: ${userData.status}`);
    
    // Find seller
    const sellersQuery = query(
      collection(db, 'sellers'),
      where('email', '==', email)
    );
    const sellersSnapshot = await getDocs(sellersQuery);
    
    if (sellersSnapshot.empty) {
      console.log('❌ No seller document found with this email');
      return;
    }
    
    const sellerDoc = sellersSnapshot.docs[0];
    const sellerData = sellerDoc.data();
    console.log(`Seller status: ${sellerData.status}`);
    
    if (userData.status === 'approved' && sellerData.status !== 'approved') {
      console.log('🔄 Updating seller status to match user status...');
      await updateDoc(sellerDoc.ref, {
        status: 'approved'
      });
      console.log('✅ Fixed! Seller status updated to approved');
    } else if (userData.status === sellerData.status) {
      console.log('✅ Both collections already have matching status');
    } else {
      console.log(`⚠️  User status: ${userData.status}, Seller status: ${sellerData.status}`);
    }
    
  } catch (error) {
    console.error('❌ Error fixing specific seller:', error);
  }
}

// Check command line arguments
const specificEmail = process.argv[2];

if (specificEmail) {
  console.log(`Fixing specific seller: ${specificEmail}`);
  fixSpecificSeller(specificEmail);
} else {
  console.log('Fixing all sellers...');
  console.log('Usage for specific seller: node fix-seller-status.js <email>');
  console.log('');
  fixSellerStatuses();
}

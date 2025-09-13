// Script to fix seller statuses using Firebase Admin SDK
// This bypasses Firestore security rules and can update the sellers collection

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// This will use the default service account if running on Google Cloud,
// or you can provide a service account key file
try {
  admin.initializeApp({
    projectId: 'e-commerce-app-5cda8',
    // If running locally, you might need to set GOOGLE_APPLICATION_CREDENTIALS
    // environment variable pointing to your service account key file
  });
} catch (error) {
  console.log('Firebase Admin already initialized or error:', error.message);
}

const db = admin.firestore();

async function fixSellerStatuses() {
  console.log('🔧 Starting seller status fix with Admin SDK...\n');
  
  try {
    // Get all approved sellers from users collection
    console.log('1. Finding approved sellers in users collection...');
    const approvedUsersQuery = db.collection('users')
      .where('role', '==', 'seller')
      .where('status', '==', 'approved');
    
    const approvedUsersSnapshot = await approvedUsersQuery.get();
    
    console.log(`Found ${approvedUsersSnapshot.size} approved sellers in users collection\n`);
    
    let fixedCount = 0;
    let alreadyCorrectCount = 0;
    let notFoundCount = 0;
    
    // For each approved user, check and update their seller document
    for (const userDoc of approvedUsersSnapshot.docs) {
      const userData = userDoc.data();
      const userEmail = userData.email;
      
      console.log(`Processing: ${userData.name} (${userEmail})`);
      
      // Find corresponding seller document
      const sellersQuery = db.collection('sellers')
        .where('email', '==', userEmail);
      
      const sellersSnapshot = await sellersQuery.get();
      
      if (sellersSnapshot.empty) {
        console.log(`  ⚠️  No seller document found for ${userEmail}`);
        notFoundCount++;
        continue;
      }
      
      const sellerDoc = sellersSnapshot.docs[0];
      const sellerData = sellerDoc.data();
      
      if (sellerData.status === 'approved') {
        console.log(`  ✅ Already approved in sellers collection`);
        alreadyCorrectCount++;
      } else {
        console.log(`  🔄 Updating seller status from "${sellerData.status}" to "approved"`);
        await sellerDoc.ref.update({
          status: 'approved',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        fixedCount++;
        console.log(`  ✅ Fixed!`);
      }
    }
    
    console.log('\n=== RESULTS ===');
    console.log(`✅ Fixed: ${fixedCount} sellers`);
    console.log(`✅ Already correct: ${alreadyCorrectCount} sellers`);
    console.log(`⚠️  Not found in sellers collection: ${notFoundCount} sellers`);
    console.log(`📱 App should now show approved status for all fixed sellers!`);
    
  } catch (error) {
    console.error('❌ Error fixing seller statuses:', error);
    
    if (error.code === 'failed-precondition' || error.message.includes('credentials')) {
      console.log('\n🔑 Authentication Issue:');
      console.log('You need to set up Firebase Admin SDK authentication.');
      console.log('Options:');
      console.log('1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable to point to service account key');
      console.log('2. Run on Google Cloud where default service account is available');
      console.log('3. Generate and download service account key from Firebase Console');
    }
  }
}

// Also provide a function to fix a specific seller by email
async function fixSpecificSeller(email) {
  console.log(`🔧 Fixing specific seller: ${email}\n`);
  
  try {
    // Find user
    const usersQuery = db.collection('users')
      .where('email', '==', email);
    
    const usersSnapshot = await usersQuery.get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No user found with this email');
      return;
    }
    
    const userData = usersSnapshot.docs[0].data();
    console.log(`User status: ${userData.status}`);
    
    // Find seller
    const sellersQuery = db.collection('sellers')
      .where('email', '==', email);
    
    const sellersSnapshot = await sellersQuery.get();
    
    if (sellersSnapshot.empty) {
      console.log('❌ No seller document found with this email');
      return;
    }
    
    const sellerDoc = sellersSnapshot.docs[0];
    const sellerData = sellerDoc.data();
    console.log(`Seller status: ${sellerData.status}`);
    
    if (userData.status === 'approved' && sellerData.status !== 'approved') {
      console.log('🔄 Updating seller status to match user status...');
      await sellerDoc.ref.update({
        status: 'approved',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
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

// Function to check if we can connect to Firestore
async function testConnection() {
  try {
    console.log('🔍 Testing Firebase Admin connection...');
    const testDoc = await db.collection('users').limit(1).get();
    console.log('✅ Connection successful!');
    return true;
  } catch (error) {
    console.error('❌ Connection failed:', error.message);
    return false;
  }
}

// Main execution
async function main() {
  const specificEmail = process.argv[2];

  // Test connection first
  const connected = await testConnection();
  if (!connected) {
    console.log('\n🔑 Setup Instructions:');
    console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
    console.log('2. Generate a new private key');
    console.log('3. Download the JSON file');
    console.log('4. Set environment variable: set GOOGLE_APPLICATION_CREDENTIALS=path\\to\\service-account-key.json');
    console.log('5. Run this script again');
    return;
  }

  if (specificEmail) {
    console.log(`Fixing specific seller: ${specificEmail}\n`);
    await fixSpecificSeller(specificEmail);
  } else {
    console.log('Fixing all sellers...');
    console.log('Usage for specific seller: node fix-seller-status-admin.js <email>\n');
    await fixSellerStatuses();
  }
  
  // Gracefully exit
  process.exit(0);
}

main().catch((error) => {
  console.error('Unexpected error:', error);
  process.exit(1);
});

// Alternative approach: Temporarily modify Firestore rules to allow admin operations
// This script will:
// 1. Backup current rules
// 2. Deploy temporary permissive rules
// 3. Run the seller status fix
// 4. Restore original rules

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Import the original fix script functionality
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

const originalRulesPath = path.join(__dirname, '..', 'e-commerce-app', 'firestore.rules');
const tempRulesPath = path.join(__dirname, 'temp-firestore.rules');
const backupRulesPath = path.join(__dirname, 'firestore-rules-backup.rules');

// Temporary permissive rules
const tempRules = `rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Temporary permissive rules for admin fix
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
`;

async function backupRules() {
  console.log('📋 Backing up current Firestore rules...');
  if (fs.existsSync(originalRulesPath)) {
    fs.copyFileSync(originalRulesPath, backupRulesPath);
    console.log('✅ Rules backed up');
  } else {
    console.log('⚠️  Original rules file not found, proceeding anyway');
  }
}

async function deployTempRules() {
  console.log('🔓 Deploying temporary permissive rules...');
  fs.writeFileSync(tempRulesPath, tempRules);
  
  try {
    // Check if Firebase CLI is available
    execSync('firebase --version', { stdio: 'pipe' });
    
    // Deploy temporary rules
    execSync(`firebase deploy --only firestore:rules --project e-commerce-app-5cda8`, {
      cwd: path.dirname(tempRulesPath),
      stdio: 'inherit'
    });
    console.log('✅ Temporary rules deployed');
    return true;
  } catch (error) {
    console.log('❌ Firebase CLI not available or deployment failed');
    console.log('You need to install Firebase CLI: npm install -g firebase-tools');
    console.log('Then login: firebase login');
    return false;
  }
}

async function restoreRules() {
  console.log('🔒 Restoring original Firestore rules...');
  try {
    if (fs.existsSync(backupRulesPath)) {
      fs.copyFileSync(backupRulesPath, originalRulesPath);
    }
    
    execSync(`firebase deploy --only firestore:rules --project e-commerce-app-5cda8`, {
      cwd: path.dirname(originalRulesPath),
      stdio: 'inherit'
    });
    console.log('✅ Original rules restored');
    
    // Cleanup temp files
    if (fs.existsSync(tempRulesPath)) fs.unlinkSync(tempRulesPath);
    if (fs.existsSync(backupRulesPath)) fs.unlinkSync(backupRulesPath);
  } catch (error) {
    console.error('❌ Failed to restore rules:', error.message);
    console.log('🔧 Manual restore needed - check firestore.rules file');
  }
}

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
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting temporary rules approach...\n');
  
  try {
    await backupRules();
    
    const deployed = await deployTempRules();
    if (!deployed) {
      console.log('\n❌ Cannot proceed without Firebase CLI');
      console.log('Please follow the Firebase Admin SDK setup instead (see FIREBASE_ADMIN_SETUP.md)');
      return;
    }
    
    // Wait a moment for rules to propagate
    console.log('⏳ Waiting for rules to propagate...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    await fixSellerStatuses();
    
  } catch (error) {
    console.error('❌ Error during execution:', error);
  } finally {
    await restoreRules();
  }
}

// Warning message
console.log('⚠️  WARNING: This script will temporarily make your Firestore database fully public!');
console.log('📝 Recommended: Use the Firebase Admin SDK approach instead (see FIREBASE_ADMIN_SETUP.md)');
console.log('❓ Continue with temporary rules approach? (y/N)');

const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

rl.question('', (answer) => {
  rl.close();
  if (answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes') {
    main();
  } else {
    console.log('👍 Cancelled. Please follow FIREBASE_ADMIN_SETUP.md for the recommended approach.');
  }
});

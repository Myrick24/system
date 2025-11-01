import { 
  collection, 
  query, 
  where, 
  orderBy, 
  getDocs, 
  doc, 
  getDoc, 
  updateDoc,
  deleteDoc,
  addDoc,
  serverTimestamp,
  writeBatch,
  getCountFromServer,
  limit
} from 'firebase/firestore';
import { db } from './firebase';
import { User } from '../types';

export class UserService {
  
  // Get all users sorted by ID
  async getAllUsers(): Promise<User[]> {
    try {
      const usersSnapshot = await getDocs(collection(db, 'users'));
      
      const users = usersSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as User));

      // Sort by ID
      users.sort((a, b) => a.id.localeCompare(b.id));
      
      // Then sort by role (buyers first, then sellers)
      users.sort((a, b) => {
        if (a.role === 'buyer' && b.role === 'seller') return -1;
        if (a.role === 'seller' && b.role === 'buyer') return 1;
        return 0;
      });

      return users;
    } catch (error) {
      console.error('Error getting all users:', error);
      return [];
    }
  }

  // Get users by role
  async getUsersByRole(role: string): Promise<User[]> {
    try {
      const usersQuery = query(
        collection(db, 'users'),
        where('role', '==', role)
      );
      const usersSnapshot = await getDocs(usersQuery);
      
      const users = usersSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as User));

      // Sort by ID
      users.sort((a, b) => a.id.localeCompare(b.id));
      
      return users;
    } catch (error) {
      console.error('Error getting users by role:', error);
      return [];
    }
  }

  // Get pending sellers
  async getPendingSellers(): Promise<User[]> {
    try {
      const pendingSellersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'seller'),
        where('status', '==', 'pending')
      );
      const pendingSellersSnapshot = await getDocs(pendingSellersQuery);
      
      const sellers = pendingSellersSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as User));

      // Sort by ID
      sellers.sort((a, b) => a.id.localeCompare(b.id));
      
      return sellers;
    } catch (error) {
      console.error('Error getting pending sellers:', error);
      return [];
    }
  }

  // Approve seller
  async approveSeller(userId: string): Promise<boolean> {
    try {
      // Update the user document
      await updateDoc(doc(db, 'users', userId), {
        status: 'approved'
      });

      // Get user data to find associated seller document
      const userDoc = await getDoc(doc(db, 'users', userId));
      if (userDoc.exists()) {
        const userData = userDoc.data();
        const userEmail = userData.email;
        
        if (userEmail) {
          // Find and update the associated seller document
          const sellersQuery = query(
            collection(db, 'sellers'),
            where('email', '==', userEmail),
            limit(1)
          );
          
          const sellerSnapshot = await getDocs(sellersQuery);
          
          if (!sellerSnapshot.empty) {
            const sellerDoc = sellerSnapshot.docs[0];
            await updateDoc(sellerDoc.ref, {
              status: 'approved'
            });
            console.log('Updated seller document status to approved for:', userEmail);
          } else {
            console.log('No seller document found for email:', userEmail);
          }
        }
      }

      // TODO: Send notification to seller about approval
      
      return true;
    } catch (error) {
      console.error('Error approving seller:', error);
      return false;
    }
  }

  // Reject seller
  async rejectSeller(userId: string): Promise<boolean> {
    try {
      // Update the user document
      await updateDoc(doc(db, 'users', userId), {
        status: 'rejected'
      });

      // Get user data to find associated seller document
      const userDoc = await getDoc(doc(db, 'users', userId));
      if (userDoc.exists()) {
        const userData = userDoc.data();
        const userEmail = userData.email;
        
        if (userEmail) {
          // Find and update the associated seller document
          const sellersQuery = query(
            collection(db, 'sellers'),
            where('email', '==', userEmail),
            limit(1)
          );
          
          const sellerSnapshot = await getDocs(sellersQuery);
          
          if (!sellerSnapshot.empty) {
            const sellerDoc = sellerSnapshot.docs[0];
            await updateDoc(sellerDoc.ref, {
              status: 'rejected'
            });
            console.log('Updated seller document status to rejected for:', userEmail);
          } else {
            console.log('No seller document found for email:', userEmail);
          }
        }
      }

      // TODO: Send notification to seller about rejection
      
      return true;
    } catch (error) {
      console.error('Error rejecting seller:', error);
      return false;
    }
  }

  // Update user status
  async updateUserStatus(userId: string, status: string): Promise<boolean> {
    try {
      await updateDoc(doc(db, 'users', userId), {
        status
      });
      return true;
    } catch (error) {
      console.error('Error updating user status:', error);
      return false;
    }
  }

  // Get user stats
  async getUserStats(): Promise<{ totalUsers: number; approvedSellers: number; pendingSellers: number }> {
    try {
      // Count total users
      const totalSnapshot = await getCountFromServer(collection(db, 'users'));
      const totalUsers = totalSnapshot.data().count;

      // Count approved sellers
      const approvedSellersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'seller'),
        where('status', '==', 'approved')
      );
      const approvedSellersSnapshot = await getCountFromServer(approvedSellersQuery);
      const approvedSellers = approvedSellersSnapshot.data().count;

      // Count pending sellers
      const pendingSellersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'seller'),
        where('status', '==', 'pending')
      );
      const pendingSellersSnapshot = await getCountFromServer(pendingSellersQuery);
      const pendingSellers = pendingSellersSnapshot.data().count;

      return {
        totalUsers,
        approvedSellers,
        pendingSellers
      };
    } catch (error) {
      console.error('Error getting user stats:', error);
      return {
        totalUsers: 0,
        approvedSellers: 0,
        pendingSellers: 0
      };
    }
  }

  // Get user data by ID
  async getUserData(userId: string): Promise<User | null> {
    try {
      const userDoc = await getDoc(doc(db, 'users', userId));
      if (!userDoc.exists()) return null;
      
      return {
        id: userDoc.id,
        ...userDoc.data()
      } as User;
    } catch (error) {
      console.error('Error getting user data:', error);
      return null;
    }
  }

  // Professional user deletion with audit trail
  async deleteUser(userId: string, adminId: string, reason: string, deleteType: 'soft' | 'hard' = 'soft'): Promise<{ success: boolean; message: string }> {
    try {
      console.log('Starting user deletion process:', { userId, adminId, deleteType, reason });
      
      // First, get user data for audit trail
      const userDoc = await getDoc(doc(db, 'users', userId));
      if (!userDoc.exists()) {
        console.error('User not found:', userId);
        return { success: false, message: 'User not found' };
      }

      const userData = userDoc.data() as User;
      console.log('User data retrieved:', userData);

      // Step 1: Handle seller-specific operations first (if applicable)
      if (userData.role === 'seller') {
        console.log('User is a seller, handling seller deletion...');
        try {
          await this.handleSellerDeletionSeparately(userId, deleteType);
        } catch (sellerError) {
          console.error('Error handling seller deletion:', sellerError);
          // Continue with user deletion even if seller operations fail
        }
      }

      // Step 2: Create audit log entry
      console.log('Creating audit log entry...');
      try {
        await addDoc(collection(db, 'admin_audit_logs'), {
          action: 'user_deletion',
          targetUserId: userId,
          targetUserEmail: userData.email,
          targetUserName: userData.name,
          targetUserRole: userData.role,
          adminId: adminId,
          deleteType: deleteType,
          reason: reason,
          timestamp: serverTimestamp(),
          ip: window.location.hostname,
          userAgent: navigator.userAgent
        });
        console.log('Audit log created successfully');
      } catch (auditError) {
        console.error('Error creating audit log:', auditError);
        // Continue with deletion even if audit log fails
      }

      // Step 3: Perform the actual user deletion/update
      const userRef = doc(db, 'users', userId);
      
      if (deleteType === 'soft') {
        console.log('Performing soft delete...');
        await updateDoc(userRef, {
          status: 'deleted',
          deletedAt: serverTimestamp(),
          deletedBy: adminId,
          deletionReason: reason,
          deletionType: deleteType,
          originalStatus: userData.status || 'active'
        });
        console.log('User soft deleted successfully');
      } else {
        console.log('Performing hard delete...');
        
        // Save to deleted_users collection first
        try {
          await addDoc(collection(db, 'deleted_users'), {
            originalId: userId,
            userData: userData,
            deletedAt: serverTimestamp(),
            deletedBy: adminId,
            reason: reason
          });
          console.log('User data archived in deleted_users collection');
        } catch (archiveError) {
          console.error('Error archiving user data:', archiveError);
        }
        
        // Then delete the user
        await deleteDoc(userRef);
        console.log('User hard deleted successfully');
      }

      const message = deleteType === 'soft' 
        ? `User ${userData.name} has been deactivated successfully`
        : `User ${userData.name} has been permanently deleted`;

      console.log('User deletion completed successfully:', message);
      return { success: true, message };

    } catch (error) {
      console.error('Error deleting user - Full error:', error);
      
      // Extract detailed error information
      let errorMessage = 'Unknown error occurred';
      
      if (error instanceof Error) {
        errorMessage = error.message;
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);
        
        // Check for specific Firebase permission errors
        if (error.message.includes('permission')) {
          errorMessage = 'Permission denied: Admin user does not have permission to delete users. Check Firestore rules and ensure user has admin role.';
        } else if (error.message.includes('auth')) {
          errorMessage = 'Authentication error: User not properly authenticated. Please login again.';
        }
      } else {
        console.error('Error object:', error);
      }
      
      console.error('Final error message:', errorMessage);
      return { 
        success: false, 
        message: `Failed to delete user: ${errorMessage}` 
      };
    }
  }

  // Handle seller-specific deletion logic separately (not in batch)
  private async handleSellerDeletionSeparately(sellerId: string, deleteType: 'soft' | 'hard'): Promise<void> {
    try {
      console.log('Handling seller deletion separately:', { sellerId, deleteType });
      
      // Get seller's products
      const productsQuery = query(
        collection(db, 'products'),
        where('sellerId', '==', sellerId)
      );
      const productsSnapshot = await getDocs(productsQuery);
      console.log(`Found ${productsSnapshot.size} products for seller`);

      // Process products one by one
      for (const productDoc of productsSnapshot.docs) {
        try {
          const productRef = doc(db, 'products', productDoc.id);
          
          if (deleteType === 'soft') {
            // Mark products as inactive
            await updateDoc(productRef, {
              status: 'seller_deleted',
              updatedAt: serverTimestamp()
            });
            console.log('Product marked as seller_deleted:', productDoc.id);
          } else {
            // Archive product first
            try {
              await addDoc(collection(db, 'archived_products'), {
                originalId: productDoc.id,
                originalSellerId: sellerId,
                productData: productDoc.data(),
                archivedAt: serverTimestamp()
              });
              console.log('Product archived:', productDoc.id);
            } catch (archiveError) {
              console.error('Error archiving product:', archiveError);
            }
            
            // Then delete
            await deleteDoc(productRef);
            console.log('Product deleted:', productDoc.id);
          }
        } catch (productError) {
          console.error('Error processing product:', productDoc.id, productError);
          // Continue with other products
        }
      }

      // Handle ongoing transactions
      const transactionsQuery = query(
        collection(db, 'transactions'),
        where('sellerId', '==', sellerId),
        where('status', 'in', ['pending', 'processing'])
      );
      const transactionsSnapshot = await getDocs(transactionsQuery);
      console.log(`Found ${transactionsSnapshot.size} transactions for seller`);

      for (const transactionDoc of transactionsSnapshot.docs) {
        try {
          const transactionRef = doc(db, 'transactions', transactionDoc.id);
          await updateDoc(transactionRef, {
            status: 'cancelled_seller_deleted',
            cancelledAt: serverTimestamp(),
            cancellationReason: 'Seller account deleted'
          });
          console.log('Transaction cancelled:', transactionDoc.id);
        } catch (transactionError) {
          console.error('Error cancelling transaction:', transactionDoc.id, transactionError);
          // Continue with other transactions
        }
      }

      console.log('Seller deletion handling completed');
    } catch (error) {
      console.error('Error handling seller deletion:', error);
      throw error;
    }
  }

  // Old batch version - kept for reference but not used
  private async handleSellerDeletion(sellerId: string, deleteType: 'soft' | 'hard', batch: any): Promise<void> {
    try {
      // Get seller's products
      const productsQuery = query(
        collection(db, 'products'),
        where('sellerId', '==', sellerId)
      );
      const productsSnapshot = await getDocs(productsQuery);

      productsSnapshot.forEach((productDoc) => {
        const productRef = doc(db, 'products', productDoc.id);
        
        if (deleteType === 'soft') {
          // Mark products as inactive
          batch.update(productRef, {
            status: 'seller_deleted',
            updatedAt: serverTimestamp()
          });
        } else {
          // Move products to archived collection
          const archivedProductRef = doc(collection(db, 'archived_products'));
          batch.set(archivedProductRef, {
            originalId: productDoc.id,
            originalSellerId: sellerId,
            productData: productDoc.data(),
            archivedAt: serverTimestamp()
          });
          batch.delete(productRef);
        }
      });

      // Handle ongoing transactions
      const transactionsQuery = query(
        collection(db, 'transactions'),
        where('sellerId', '==', sellerId),
        where('status', 'in', ['pending', 'processing'])
      );
      const transactionsSnapshot = await getDocs(transactionsQuery);

      transactionsSnapshot.forEach((transactionDoc) => {
        const transactionRef = doc(db, 'transactions', transactionDoc.id);
        batch.update(transactionRef, {
          status: 'cancelled_seller_deleted',
          cancelledAt: serverTimestamp(),
          cancellationReason: 'Seller account deleted'
        });
      });

    } catch (error) {
      console.error('Error handling seller deletion:', error);
      throw error;
    }
  }

  // Restore soft-deleted user
  async restoreUser(userId: string, adminId: string): Promise<{ success: boolean; message: string }> {
    try {
      const userDoc = await getDoc(doc(db, 'users', userId));
      if (!userDoc.exists()) {
        return { success: false, message: 'User not found' };
      }

      const userData = userDoc.data() as User;
      if (userData.status !== 'deleted') {
        return { success: false, message: 'User is not deleted' };
      }

      const batch = writeBatch(db);

      // Restore user
      const userRef = doc(db, 'users', userId);
      batch.update(userRef, {
        status: userData.originalStatus || 'active',
        restoredAt: serverTimestamp(),
        restoredBy: adminId,
        deletedAt: null,
        deletedBy: null,
        deletionReason: null,
        originalStatus: null
      });

      // Create audit trail
      const auditRef = doc(collection(db, 'admin_audit_logs'));
      batch.set(auditRef, {
        action: 'user_restoration',
        targetUserId: userId,
        targetUserName: userData.name,
        targetUserEmail: userData.email,
        targetUserRole: userData.role,
        deleteType: (userData as any).deletionType || 'soft',
        adminId: adminId,
        timestamp: serverTimestamp()
      });

      // If user was a seller, restore their products
      if (userData.role === 'seller') {
        const productsQuery = query(
          collection(db, 'products'),
          where('sellerId', '==', userId),
          where('status', '==', 'seller_deleted')
        );
        const productsSnapshot = await getDocs(productsQuery);

        productsSnapshot.forEach((productDoc) => {
          const productRef = doc(db, 'products', productDoc.id);
          batch.update(productRef, {
            status: 'approved', // or whatever the original status was
            updatedAt: serverTimestamp()
          });
        });
      }

      await batch.commit();

      return { 
        success: true, 
        message: `User ${userData.name} has been restored successfully` 
      };

    } catch (error) {
      console.error('Error restoring user:', error);
      return { 
        success: false, 
        message: `Failed to restore user: ${error instanceof Error ? error.message : 'Unknown error'}` 
      };
    }
  }

  // Get deletion audit logs
  async getDeletionAuditLogs(limit: number = 50): Promise<any[]> {
    try {
      console.log('Fetching audit logs...');
      
      // First, try to get all audit logs without complex query
      const auditQuery = query(
        collection(db, 'admin_audit_logs'),
        orderBy('timestamp', 'desc')
      );
      
      const auditSnapshot = await getDocs(auditQuery);
      console.log(`Found ${auditSnapshot.size} total audit logs`);
      
      // Filter client-side for now to avoid Firestore index issues
      const allLogs = auditSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as any));
      
      // Filter for deletion and restoration actions
      const filteredLogs = allLogs.filter((log: any) => 
        log.action === 'user_deletion' || log.action === 'user_restoration'
      );
      
      console.log(`Found ${filteredLogs.length} deletion/restoration logs`);
      
      // Return limited results
      return filteredLogs.slice(0, limit);
    } catch (error) {
      console.error('Error getting audit logs:', error);
      
      // Fallback: try to get logs without orderBy
      try {
        console.log('Trying fallback query...');
        const fallbackQuery = query(collection(db, 'admin_audit_logs'));
        const fallbackSnapshot = await getDocs(fallbackQuery);
        
        const allLogs = fallbackSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        } as any));
        
        // Filter and sort client-side
        const filteredLogs = allLogs
          .filter((log: any) => log.action === 'user_deletion' || log.action === 'user_restoration')
          .sort((a: any, b: any) => {
            const timeA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp || 0);
            const timeB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp || 0);
            return timeB.getTime() - timeA.getTime();
          });
        
        console.log(`Fallback found ${filteredLogs.length} logs`);
        return filteredLogs.slice(0, limit);
      } catch (fallbackError) {
        console.error('Fallback query also failed:', fallbackError);
        return [];
      }
    }
  }

  // Create a test audit log entry for debugging
  async createTestAuditLog(): Promise<{ success: boolean; message: string }> {
    try {
      console.log('Creating test audit log...');
      
      const testAuditEntry = {
        action: 'user_deletion',
        targetUserId: 'test-user-id',
        targetUserData: {
          name: 'Test User',
          email: 'test@example.com',
          role: 'buyer',
          status: 'active'
        },
        adminId: 'test-admin-id',
        deleteType: 'soft',
        reason: 'Test audit log entry for debugging',
        timestamp: serverTimestamp(),
        ip: window.location.hostname,
        userAgent: navigator.userAgent
      };

      await addDoc(collection(db, 'admin_audit_logs'), testAuditEntry);
      console.log('Test audit log created successfully');
      
      return { 
        success: true, 
        message: 'Test audit log created successfully' 
      };
    } catch (error) {
      console.error('Error creating test audit log:', error);
      return { 
        success: false, 
        message: `Failed to create test audit log: ${error instanceof Error ? error.message : 'Unknown error'}` 
      };
    }
  }
}

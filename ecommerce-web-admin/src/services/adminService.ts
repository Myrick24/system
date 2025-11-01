// Admin Service
import { collection, query, where, getDocs, orderBy, limit, doc, getDoc } from 'firebase/firestore';
import { db } from './firebase';
import { DashboardStats, RecentActivity, User } from '../types';

export class AdminService {
  
  // Check if current user is admin
  async isAdmin(userId: string): Promise<boolean> {
    try {
      console.log('Checking admin status for userId:', userId);
      
      // Get the specific user document using their Firebase UID as the document ID
      const userDoc = await getDoc(doc(db, 'users', userId));
      
      if (!userDoc.exists()) {
        console.log('User document not found:', userId);
        return false;
      }
      
      const userData = userDoc.data();
      console.log('User data found:', { userId, role: userData?.role });
      
      // Check if user has admin role
      if (userData?.role === 'admin') {
        console.log('User confirmed as admin');
        return true;
      } else {
        console.log('User is not admin. Role:', userData?.role);
        return false;
      }
      
    } catch (error) {
      console.error('Error checking admin status:', error);
      return false;
    }
  }

  // Get dashboard statistics
  async getDashboardStats(): Promise<DashboardStats> {
    try {
      console.log('Fetching dashboard statistics from Firestore...');

      // Fetch total users
      const usersSnapshot = await getDocs(collection(db, 'users'));
      const totalUsers = usersSnapshot.size;

      // Fetch approved sellers
      const approvedSellersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'seller'),
        where('status', '==', 'approved')
      );
      const approvedSellersSnapshot = await getDocs(approvedSellersQuery);
      const approvedSellers = approvedSellersSnapshot.size;

      // Fetch pending sellers
      const pendingSellersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'seller'),
        where('status', '==', 'pending')
      );
      const pendingSellersSnapshot = await getDocs(pendingSellersQuery);
      const pendingSellers = pendingSellersSnapshot.size;

      // Fetch active listings (products)
      const activeListingsQuery = query(
        collection(db, 'products'),
        where('status', '==', 'approved')
      );
      const activeListingsSnapshot = await getDocs(activeListingsQuery);
      const activeListings = activeListingsSnapshot.size;

      // Fetch completed transactions
      const completedTransactionsQuery = query(
        collection(db, 'transactions'),
        where('status', '==', 'completed')
      );
      const completedTransactionsSnapshot = await getDocs(completedTransactionsQuery);
      const completedTransactions = completedTransactionsSnapshot.size;

      const stats = {
        totalUsers,
        approvedSellers,
        pendingSellers,
        activeListings,
        completedTransactions
      };

      console.log('Dashboard stats:', stats);
      return stats;

    } catch (error) {
      console.error('Error getting dashboard stats:', error);
      return {
        totalUsers: 0,
        approvedSellers: 0,
        pendingSellers: 0,
        activeListings: 0,
        completedTransactions: 0
      };
    }
  }

  // Get recent activity
  async getRecentActivity(): Promise<RecentActivity[]> {
    try {
      console.log('Fetching recent activity from Firestore...');
      const activities: RecentActivity[] = [];

      // Get recent user registrations
      try {
        const recentUsersQuery = query(
          collection(db, 'users'),
          orderBy('createdAt', 'desc'),
          limit(5)
        );
        const recentUsersSnapshot = await getDocs(recentUsersQuery);
        
        recentUsersSnapshot.forEach((doc) => {
          const userData = doc.data();
          activities.push({
            id: `user_${doc.id}`,
            type: 'user_registration',
            user: {
              id: doc.id,
              name: userData.name || 'Unknown User',
              role: userData.role || 'buyer'
            },
            timestamp: userData.createdAt || new Date()
          });
        });
      } catch (error) {
        console.log('Error fetching recent users:', error);
      }

      // Get recent pending sellers
      try {
        const pendingSellersQuery = query(
          collection(db, 'users'),
          where('role', '==', 'seller'),
          where('status', '==', 'pending'),
          orderBy('createdAt', 'desc'),
          limit(3)
        );
        const pendingSellersSnapshot = await getDocs(pendingSellersQuery);
        
        pendingSellersSnapshot.forEach((doc) => {
          const userData = doc.data();
          activities.push({
            id: `seller_${doc.id}`,
            type: 'pending_seller',
            user: {
              id: doc.id,
              name: userData.name || 'Unknown Seller',
              role: 'seller'
            },
            timestamp: userData.createdAt || new Date()
          });
        });
      } catch (error) {
        console.log('Error fetching pending sellers:', error);
      }

      // Get recent transactions
      try {
        const recentTransactionsQuery = query(
          collection(db, 'transactions'),
          orderBy('timestamp', 'desc'),
          limit(5)
        );
        const recentTransactionsSnapshot = await getDocs(recentTransactionsQuery);
        
        recentTransactionsSnapshot.forEach((doc) => {
          const transactionData = doc.data();
          activities.push({
            id: `transaction_${doc.id}`,
            type: 'transaction',
            transaction: {
              id: doc.id,
              amount: transactionData.amount || 0,
              status: transactionData.status || 'pending'
            },
            timestamp: transactionData.timestamp || new Date()
          });
        });
      } catch (error) {
        console.log('Error fetching recent transactions:', error);
      }

      // Get recent product listings
      try {
        const recentProductsQuery = query(
          collection(db, 'products'),
          orderBy('createdAt', 'desc'),
          limit(3)
        );
        const recentProductsSnapshot = await getDocs(recentProductsQuery);
        
        recentProductsSnapshot.forEach((doc) => {
          const productData = doc.data();
          activities.push({
            id: `product_${doc.id}`,
            type: 'product_listing',
            product: {
              id: doc.id,
              name: productData.name || 'Unknown Product',
              status: productData.status || 'pending'
            },
            timestamp: productData.createdAt || new Date()
          });
        });
      } catch (error) {
        console.log('Error fetching recent products:', error);
      }

      // Sort activities by timestamp (most recent first)
      activities.sort((a, b) => {
        const timeA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp);
        const timeB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp);
        return timeB.getTime() - timeA.getTime();
      });

      // Return top 10 most recent activities
      const recentActivities = activities.slice(0, 10);
      console.log('Recent activities:', recentActivities);
      return recentActivities;

    } catch (error) {
      console.error('Error getting recent activity:', error);
      return [];
    }
  }

  // Add sub-admin
  async addSubAdmin(email: string, password: string, name: string): Promise<boolean> {
    try {
      // TODO: Implement Firebase auth when dependencies are resolved
      console.log('Adding sub-admin:', { email, name });
      return true;
    } catch (error) {
      console.error('Error adding sub-admin:', error);
      return false;
    }
  }

  // Get all admin users
  async getAllAdmins(): Promise<User[]> {
    try {
      // TODO: Implement Firebase query when dependencies are resolved
      return [];
    } catch (error) {
      console.error('Error getting all admins:', error);
      return [];
    }
  }

  // Remove sub-admin
  async removeSubAdmin(userId: string): Promise<boolean> {
    try {
      // TODO: Implement Firebase update when dependencies are resolved
      console.log('Removing sub-admin:', userId);
      return true;
    } catch (error) {
      console.error('Error removing sub-admin:', error);
      return false;
    }
  }
}

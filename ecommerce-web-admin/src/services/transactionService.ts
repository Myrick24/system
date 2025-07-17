import { 
  collection, 
  query, 
  where, 
  orderBy, 
  getDocs, 
  doc, 
  updateDoc,
  getCountFromServer
} from 'firebase/firestore';
import { db } from './firebase';
import { Transaction } from '../types';

export class TransactionService {
  
  // Get all transactions
  async getAllTransactions(): Promise<Transaction[]> {
    try {
      const transactionsSnapshot = await getDocs(
        query(collection(db, 'transactions'), orderBy('timestamp', 'desc'))
      );
      
      return transactionsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Transaction));
    } catch (error) {
      console.error('Error getting all transactions:', error);
      return [];
    }
  }

  // Get transactions by status
  async getTransactionsByStatus(status: string): Promise<Transaction[]> {
    try {
      const transactionsQuery = query(
        collection(db, 'transactions'),
        where('status', '==', status),
        orderBy('timestamp', 'desc')
      );
      const transactionsSnapshot = await getDocs(transactionsQuery);
      
      return transactionsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Transaction));
    } catch (error) {
      console.error('Error getting transactions by status:', error);
      return [];
    }
  }

  // Get transactions by date range
  async getTransactionsByDateRange(startDate: Date, endDate: Date): Promise<Transaction[]> {
    try {
      const transactionsQuery = query(
        collection(db, 'transactions'),
        where('timestamp', '>=', startDate),
        where('timestamp', '<=', endDate),
        orderBy('timestamp', 'desc')
      );
      const transactionsSnapshot = await getDocs(transactionsQuery);
      
      return transactionsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Transaction));
    } catch (error) {
      console.error('Error getting transactions by date range:', error);
      return [];
    }
  }

  // Update transaction status
  async updateTransactionStatus(transactionId: string, status: string): Promise<boolean> {
    try {
      await updateDoc(doc(db, 'transactions', transactionId), {
        status
      });
      return true;
    } catch (error) {
      console.error('Error updating transaction status:', error);
      return false;
    }
  }

  // Get transaction stats
  async getTransactionStats(): Promise<{ 
    totalTransactions: number; 
    completedTransactions: number; 
    pendingTransactions: number;
    totalRevenue: number;
  }> {
    try {
      // Count total transactions
      const totalSnapshot = await getCountFromServer(collection(db, 'transactions'));
      const totalTransactions = totalSnapshot.data().count;

      // Count completed transactions
      const completedTransactionsQuery = query(
        collection(db, 'transactions'),
        where('status', '==', 'completed')
      );
      const completedTransactionsSnapshot = await getCountFromServer(completedTransactionsQuery);
      const completedTransactions = completedTransactionsSnapshot.data().count;

      // Count pending transactions
      const pendingTransactionsQuery = query(
        collection(db, 'transactions'),
        where('status', '==', 'pending')
      );
      const pendingTransactionsSnapshot = await getCountFromServer(pendingTransactionsQuery);
      const pendingTransactions = pendingTransactionsSnapshot.data().count;

      // Calculate total revenue (from completed transactions)
      const completedTransactionsDocs = await getDocs(completedTransactionsQuery);
      const totalRevenue = completedTransactionsDocs.docs.reduce((sum, doc) => {
        const data = doc.data();
        return sum + (data.amount || 0);
      }, 0);

      return {
        totalTransactions,
        completedTransactions,
        pendingTransactions,
        totalRevenue
      };
    } catch (error) {
      console.error('Error getting transaction stats:', error);
      return {
        totalTransactions: 0,
        completedTransactions: 0,
        pendingTransactions: 0,
        totalRevenue: 0
      };
    }
  }
}

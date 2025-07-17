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
import { Product } from '../types';

export class ProductService {
  
  // Get all products
  async getAllProducts(): Promise<Product[]> {
    try {
      const productsSnapshot = await getDocs(collection(db, 'products'));
      
      return productsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Product));
    } catch (error) {
      console.error('Error getting all products:', error);
      return [];
    }
  }

  // Get products by status
  async getProductsByStatus(status: string): Promise<Product[]> {
    try {
      const productsQuery = query(
        collection(db, 'products'),
        where('status', '==', status),
        orderBy('createdAt', 'desc')
      );
      const productsSnapshot = await getDocs(productsQuery);
      
      return productsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Product));
    } catch (error) {
      console.error('Error getting products by status:', error);
      return [];
    }
  }

  // Approve product
  async approveProduct(productId: string): Promise<boolean> {
    try {
      await updateDoc(doc(db, 'products', productId), {
        status: 'approved'
      });

      // TODO: Send notification to seller about approval
      
      return true;
    } catch (error) {
      console.error('Error approving product:', error);
      return false;
    }
  }

  // Reject product
  async rejectProduct(productId: string): Promise<boolean> {
    try {
      await updateDoc(doc(db, 'products', productId), {
        status: 'rejected'
      });

      // TODO: Send notification to seller about rejection
      
      return true;
    } catch (error) {
      console.error('Error rejecting product:', error);
      return false;
    }
  }

  // Get product stats
  async getProductStats(): Promise<{ totalProducts: number; activeListings: number; pendingProducts: number }> {
    try {
      // Count total products
      const totalSnapshot = await getCountFromServer(collection(db, 'products'));
      const totalProducts = totalSnapshot.data().count;

      // Count active listings
      const activeListingsQuery = query(
        collection(db, 'products'),
        where('status', '==', 'approved')
      );
      const activeListingsSnapshot = await getCountFromServer(activeListingsQuery);
      const activeListings = activeListingsSnapshot.data().count;

      // Count pending products
      const pendingProductsQuery = query(
        collection(db, 'products'),
        where('status', '==', 'pending')
      );
      const pendingProductsSnapshot = await getCountFromServer(pendingProductsQuery);
      const pendingProducts = pendingProductsSnapshot.data().count;

      return {
        totalProducts,
        activeListings,
        pendingProducts
      };
    } catch (error) {
      console.error('Error getting product stats:', error);
      return {
        totalProducts: 0,
        activeListings: 0,
        pendingProducts: 0
      };
    }
  }

  // Delete product
  async deleteProduct(productId: string): Promise<boolean> {
    try {
      await updateDoc(doc(db, 'products', productId), {
        status: 'deleted'
      });
      return true;
    } catch (error) {
      console.error('Error deleting product:', error);
      return false;
    }
  }
}

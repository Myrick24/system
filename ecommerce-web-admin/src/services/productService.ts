import { 
  collection, 
  query, 
  where, 
  orderBy, 
  getDocs, 
  doc, 
  updateDoc,
  getCountFromServer,
  getDoc
} from 'firebase/firestore';
import { db } from './firebase';
import { Product } from '../types';
import { NotificationService } from './notificationService';

export class ProductService {
  private notificationService: NotificationService;

  constructor() {
    this.notificationService = new NotificationService();
  }
  
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
      // First, get the product details
      const productRef = doc(db, 'products', productId);
      const productSnap = await getDoc(productRef);
      
      if (!productSnap.exists()) {
        console.error('Product not found');
        return false;
      }

      const productData = productSnap.data() as Product;
      const sellerId = productData.sellerId;
      const productName = productData.name;

      // Update product status
      await updateDoc(productRef, {
        status: 'approved'
      });

      // Send notification to seller about approval
      await this.notificationService.sendNotificationToUser(
        sellerId,
        '🎉 Product Approved!',
        `Great news! Your product "${productName}" has been approved and is now live for buyers to purchase.`,
        'product_approval',
        { productId, productName }
      );

      // Send notification to all buyers about new product
      await this.notifyBuyersAboutNewProduct(productId, productName, productData.category);
      
      return true;
    } catch (error) {
      console.error('Error approving product:', error);
      return false;
    }
  }

  // Reject product
  async rejectProduct(productId: string, reason?: string): Promise<boolean> {
    try {
      // First, get the product details
      const productRef = doc(db, 'products', productId);
      const productSnap = await getDoc(productRef);
      
      if (!productSnap.exists()) {
        console.error('Product not found');
        return false;
      }

      const productData = productSnap.data() as Product;
      const sellerId = productData.sellerId;
      const productName = productData.name;

      // Update product status
      await updateDoc(productRef, {
        status: 'rejected',
        rejectionReason: reason || 'Not specified'
      });

      // Send notification to seller about rejection
      const rejectionMessage = reason 
        ? `Your product "${productName}" needs some changes before approval. Reason: ${reason}`
        : `Your product "${productName}" requires some changes before approval. Please review and resubmit.`;

      await this.notificationService.sendNotificationToUser(
        sellerId,
        '⚠️ Product Needs Attention',
        rejectionMessage,
        'product_rejection',
        { productId, productName, reason: reason || 'Not specified' }
      );
      
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

  // Helper method to notify all buyers about new product
  private async notifyBuyersAboutNewProduct(productId: string, productName: string, category: string): Promise<void> {
    try {
      // Get all users with buyer role
      const usersQuery = query(
        collection(db, 'users'),
        where('role', '==', 'buyer')
      );
      const usersSnapshot = await getDocs(usersQuery);

      // Send notification to each buyer
      const notificationPromises = usersSnapshot.docs.map(async (userDoc) => {
        const userId = userDoc.id;
        await this.notificationService.sendNotificationToUser(
          userId,
          '🆕 New Product Available!',
          `Check out our new product: "${productName}" in ${category} category. Shop now!`,
          'product_approval',
          { productId, productName, category, type: 'new_product_listing' }
        );
      });

      await Promise.all(notificationPromises);
      console.log(`Notified ${usersSnapshot.docs.length} buyers about new product: ${productName}`);
    } catch (error) {
      console.error('Error notifying buyers about new product:', error);
      // Don't throw error, just log it - notification failure shouldn't block product approval
    }
  }
}

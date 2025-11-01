import { collection, query, getDocs, orderBy, where, doc, getDoc, updateDoc, Timestamp } from 'firebase/firestore';
import { db } from './firebase';

export interface Order {
  id: string;
  buyerId: string;
  buyerName?: string;
  buyerEmail?: string;
  sellerId: string;
  sellerName?: string;
  coopName?: string;
  productId: string;
  productName: string;
  productImage?: string;
  quantity: number;
  quantityLabel?: string; // e.g., "5kg", "10pcs", "2L"
  totalAmount: number;
  price: number;
  status: 'pending' | 'processing' | 'shipped' | 'delivered' | 'cancelled' | 'rejected';
  paymentMethod?: string;
  deliveryMethod?: string;
  deliveryAddress?: string;
  meetupLocation?: string;
  timestamp: any;
  updatedAt?: any;
  notes?: string;
  statusUpdates?: Array<{ status: string; timestamp: any }>;
}

export class OrderService {
  async getAllOrders(): Promise<Order[]> {
    try {
      const ordersQuery = query(
        collection(db, 'orders'),
        orderBy('timestamp', 'desc')
      );

      const snapshot = await getDocs(ordersQuery);
      const orders: Order[] = [];

      for (const docSnapshot of snapshot.docs) {
        const orderData = docSnapshot.data();
        
        // Fetch buyer and seller info
        let buyerName = 'Unknown Buyer';
        let buyerEmail = 'No email';
        let sellerName = 'Unknown Seller';
        let coopName = '';

        try {
          if (orderData.buyerId) {
            const buyerDoc = await getDoc(doc(db, 'users', orderData.buyerId));
            if (buyerDoc.exists()) {
              const buyerInfo = buyerDoc.data();
              buyerName = buyerInfo.name || buyerInfo.fullName || 'Unknown Buyer';
              buyerEmail = buyerInfo.email || 'No email';
            }
          }

          if (orderData.sellerId) {
            const sellerDoc = await getDoc(doc(db, 'users', orderData.sellerId));
            if (sellerDoc.exists()) {
              const sellerInfo = sellerDoc.data();
              sellerName = sellerInfo.name || sellerInfo.fullName || 'Unknown Seller';
              // Check if seller has a cooperative name (if it's a cooperative user)
              if (sellerInfo.role === 'cooperative' && sellerInfo.name) {
                coopName = sellerInfo.name;
              }
            }
          }
        } catch (error) {
          console.error('Error fetching user info:', error);
        }

        orders.push({
          id: docSnapshot.id,
          ...orderData,
          buyerName,
          buyerEmail,
          sellerName,
          coopName,
          quantityLabel: orderData.quantity && orderData.unit 
            ? `${orderData.quantity} ${orderData.unit}` 
            : orderData.quantityLabel,
        } as Order);

      }

      console.log(`📦 Loaded ${orders.length} orders`);
      return orders;
    } catch (error) {
      console.error('Error loading all orders:', error);
      throw error;
    }
  }

  async getOrdersByStatus(status: string): Promise<Order[]> {
    try {
      const ordersQuery = query(
        collection(db, 'orders'),
        where('status', '==', status),
        orderBy('timestamp', 'desc')
      );

      const snapshot = await getDocs(ordersQuery);
      const orders: Order[] = [];

      for (const docSnapshot of snapshot.docs) {
        const orderData = docSnapshot.data();
        
        let buyerName = 'Unknown Buyer';
        let buyerEmail = 'No email';
        let sellerName = 'Unknown Seller';
        let coopName = '';

        try {
          if (orderData.buyerId) {
            const buyerDoc = await getDoc(doc(db, 'users', orderData.buyerId));
            if (buyerDoc.exists()) {
              const buyerInfo = buyerDoc.data();
              buyerName = buyerInfo.name || buyerInfo.fullName || 'Unknown Buyer';
              buyerEmail = buyerInfo.email || 'No email';
            }
          }

          if (orderData.sellerId) {
            const sellerDoc = await getDoc(doc(db, 'users', orderData.sellerId));
            if (sellerDoc.exists()) {
              const sellerInfo = sellerDoc.data();
              sellerName = sellerInfo.name || sellerInfo.fullName || 'Unknown Seller';
              // Check if seller has a cooperative name (if it's a cooperative user)
              if (sellerInfo.role === 'cooperative' && sellerInfo.name) {
                coopName = sellerInfo.name;
              }
            }
          }
        } catch (error) {
          console.error('Error fetching user info:', error);
        }

        orders.push({
          id: docSnapshot.id,
          ...orderData,
          buyerName,
          buyerEmail,
          sellerName,
          coopName,
          quantityLabel: orderData.quantity && orderData.unit 
            ? `${orderData.quantity} ${orderData.unit}` 
            : orderData.quantityLabel,
        } as Order);
      }

      return orders;
    } catch (error) {
      console.error(`Error loading orders with status ${status}:`, error);
      throw error;
    }
  }

  async updateOrderStatus(orderId: string, newStatus: string): Promise<boolean> {
    try {
      const orderRef = doc(db, 'orders', orderId);
      await updateDoc(orderRef, {
        status: newStatus,
        updatedAt: Timestamp.now(),
      });
      console.log(`✅ Order ${orderId} updated to status: ${newStatus}`);
      return true;
    } catch (error) {
      console.error('Error updating order status:', error);
      throw error;
    }
  }

  async updateOrderNotes(orderId: string, notes: string): Promise<boolean> {
    try {
      const orderRef = doc(db, 'orders', orderId);
      await updateDoc(orderRef, {
        notes,
        updatedAt: Timestamp.now(),
      });
      return true;
    } catch (error) {
      console.error('Error updating order notes:', error);
      throw error;
    }
  }
}

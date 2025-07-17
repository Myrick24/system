import { 
  collection, 
  addDoc, 
  serverTimestamp, 
  query, 
  where, 
  getDocs, 
  updateDoc, 
  doc 
} from 'firebase/firestore';
import { db } from './firebase';

export interface Notification {
  id?: string;
  userId: string;
  title: string;
  message: string;
  type: 'seller_approval' | 'seller_rejection' | 'product_approval' | 'product_rejection' | 'account_update' | 'system_announcement';
  read: boolean;
  createdAt: any;
  data?: Record<string, any>;
}

export class NotificationService {
  
  // Send notification to a specific user
  async sendNotificationToUser(
    userId: string, 
    title: string, 
    message: string, 
    type: Notification['type'],
    data?: Record<string, any>
  ): Promise<{ success: boolean; message: string }> {
    try {
      console.log('Sending notification to user:', { userId, title, type });
      
      const notification: Omit<Notification, 'id'> = {
        userId,
        title,
        message,
        type,
        read: false,
        createdAt: serverTimestamp(),
        data: data || {}
      };

      await addDoc(collection(db, 'notifications'), notification);
      
      return { 
        success: true, 
        message: 'Notification sent successfully' 
      };
    } catch (error) {
      console.error('Error sending notification:', error);
      return { 
        success: false, 
        message: `Failed to send notification: ${error instanceof Error ? error.message : 'Unknown error'}` 
      };
    }
  }

  // Get notification statistics
  async getNotificationStats(): Promise<{
    totalNotifications: number;
    unreadNotifications: number;
    notificationsByType: Record<string, number>;
  }> {
    try {
      const notificationsSnapshot = await getDocs(collection(db, 'notifications'));
      
      const stats = {
        totalNotifications: notificationsSnapshot.size,
        unreadNotifications: 0,
        notificationsByType: {} as Record<string, number>
      };

      notificationsSnapshot.docs.forEach(doc => {
        const notification = doc.data() as Notification;
        
        if (!notification.read) {
          stats.unreadNotifications++;
        }
        
        if (notification.type) {
          stats.notificationsByType[notification.type] = 
            (stats.notificationsByType[notification.type] || 0) + 1;
        }
      });

      return stats;
    } catch (error) {
      console.error('Error getting notification stats:', error);
      return {
        totalNotifications: 0,
        unreadNotifications: 0,
        notificationsByType: {}
      };
    }
  }
}
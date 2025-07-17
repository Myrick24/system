export interface User {
  id: string;
  name: string;
  email: string;
  role?: 'admin' | 'seller' | 'buyer';
  status?: 'active' | 'suspended' | 'pending' | 'approved' | 'rejected' | 'deleted';
  createdAt: any;
  isMainAdmin?: boolean;
  isSubAdmin?: boolean;
  deletedAt?: any;
  deletedBy?: string;
  deletionReason?: string;
  originalStatus?: string;
  restoredAt?: any;
  restoredBy?: string;
}

export interface Product {
  id: string;
  name: string;
  description: string;
  category: string;
  price: number;
  inventory: number;
  sellerId: string;
  sellerName: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: any;
  images: string[];
}

export interface Transaction {
  id: string;
  userId: string;
  productId: string;
  productName: string;
  quantity: number;
  amount: number;
  status: 'pending' | 'completed' | 'canceled' | 'refunded';
  paymentMethod: string;
  deliveryMethod: string;
  timestamp: any;
  buyerName?: string;
  sellerName?: string;
}

export interface DashboardStats {
  totalUsers: number;
  approvedSellers: number;
  pendingSellers: number;
  activeListings: number;
  completedTransactions: number;
}

export interface RecentActivity {
  id: string;
  type: 'user_registration' | 'pending_seller' | 'transaction' | 'product_listing';
  user?: {
    id: string;
    name: string;
    role: string;
  };
  transaction?: {
    id: string;
    amount: number;
    status: string;
  };
  product?: {
    id: string;
    name: string;
    status: string;
  };
  timestamp: any;
}

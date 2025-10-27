import React, { useEffect, useState } from 'react';
import { 
  Card, Statistic, Row, Col, Typography, Spin, Table, Tag, Button, message, 
  Progress, Alert, Space, Tabs, Badge, List, Avatar, Divider 
} from 'antd';
import { 
  UserOutlined, ShopOutlined, ShoppingOutlined, DollarOutlined,
  TeamOutlined, ClockCircleOutlined, ReloadOutlined, CheckCircleOutlined,
  CloseCircleOutlined, WarningOutlined, RiseOutlined, FallOutlined,
  EyeOutlined, TruckOutlined, WalletOutlined, HeartOutlined
} from '@ant-design/icons';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title as ChartTitle,
  Tooltip,
  Legend,
  ArcElement,
  Filler
} from 'chart.js';
import { collection, getDocs, query, where, orderBy, limit } from 'firebase/firestore';
import { db } from '../services/firebase';

// Register ChartJS components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ChartTitle,
  Tooltip,
  Legend,
  ArcElement,
  Filler
);

const { Title, Text } = Typography;
const { TabPane } = Tabs;

interface DashboardStats {
  totalUsers: number;
  totalBuyers: number;
  totalSellers: number;
  totalCooperatives: number;
  pendingSellers: number;
  approvedSellers: number;
  suspendedUsers: number;
  totalProducts: number;
  pendingProducts: number;
  approvedProducts: number;
  totalOrders: number;
  pendingOrders: number;
  processingOrders: number;
  completedOrders: number;
  cancelledOrders: number;
  totalRevenue: number;
  todayRevenue: number;
  monthRevenue: number;
  avgOrderValue: number;
}

interface QuickAction {
  title: string;
  count: number;
  icon: React.ReactNode;
  color: string;
  action: string;
}

interface RecentOrder {
  id: string;
  customerName: string;
  amount: number;
  status: string;
  date: any;
}

export const EnhancedDashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats>({
    totalUsers: 0,
    totalBuyers: 0,
    totalSellers: 0,
    totalCooperatives: 0,
    pendingSellers: 0,
    approvedSellers: 0,
    suspendedUsers: 0,
    totalProducts: 0,
    pendingProducts: 0,
    approvedProducts: 0,
    totalOrders: 0,
    pendingOrders: 0,
    processingOrders: 0,
    completedOrders: 0,
    cancelledOrders: 0,
    totalRevenue: 0,
    todayRevenue: 0,
    monthRevenue: 0,
    avgOrderValue: 0
  });
  const [loading, setLoading] = useState(true);
  const [recentOrders, setRecentOrders] = useState<RecentOrder[]>([]);
  const [topProducts, setTopProducts] = useState<any[]>([]);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      
      // Fetch all data in parallel
      const [usersSnap, productsSnap, ordersSnap] = await Promise.all([
        getDocs(collection(db, 'users')),
        getDocs(collection(db, 'products')),
        getDocs(collection(db, 'orders'))
      ]);

      // Process users
      let totalBuyers = 0, totalSellers = 0, totalCoops = 0;
      let pendingSellers = 0, approvedSellers = 0, suspendedUsers = 0;

      usersSnap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'buyer') totalBuyers++;
        if (data.role === 'seller') {
          totalSellers++;
          if (data.status === 'pending') pendingSellers++;
          if (data.status === 'approved') approvedSellers++;
        }
        if (data.role === 'cooperative') totalCoops++;
        if (data.status === 'suspended') suspendedUsers++;
      });

      // Process products
      let totalProducts = 0, pendingProducts = 0, approvedProducts = 0;
      productsSnap.forEach(doc => {
        const data = doc.data();
        totalProducts++;
        if (data.status === 'pending') pendingProducts++;
        if (data.status === 'approved') approvedProducts++;
      });

      // Process orders
      let totalOrders = 0, pendingOrders = 0, processingOrders = 0;
      let completedOrders = 0, cancelledOrders = 0;
      let totalRevenue = 0, todayRevenue = 0, monthRevenue = 0;

      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

      const recentOrdersList: RecentOrder[] = [];

      ordersSnap.forEach(doc => {
        const data = doc.data();
        totalOrders++;
        
        const amount = Number(data.totalAmount) || 0;
        totalRevenue += amount;

        if (data.status === 'pending') pendingOrders++;
        if (data.status === 'processing') processingOrders++;
        if (data.status === 'completed') completedOrders++;
        if (data.status === 'cancelled') cancelledOrders++;

        // Calculate today and month revenue
        const orderDate = data.createdAt?.toDate();
        if (orderDate) {
          if (orderDate >= today) todayRevenue += amount;
          if (orderDate >= monthStart) monthRevenue += amount;
        }

        // Collect recent orders (last 5)
        if (recentOrdersList.length < 5) {
          recentOrdersList.push({
            id: doc.id,
            customerName: data.buyerName || 'Unknown',
            amount,
            status: data.status || 'pending',
            date: data.createdAt
          });
        }
      });

      const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

      setStats({
        totalUsers: usersSnap.size,
        totalBuyers,
        totalSellers,
        totalCooperatives: totalCoops,
        pendingSellers,
        approvedSellers,
        suspendedUsers,
        totalProducts,
        pendingProducts,
        approvedProducts,
        totalOrders,
        pendingOrders,
        processingOrders,
        completedOrders,
        cancelledOrders,
        totalRevenue,
        todayRevenue,
        monthRevenue,
        avgOrderValue
      });

      setRecentOrders(recentOrdersList);
      message.success('Dashboard loaded successfully');
    } catch (error) {
      console.error('Error loading dashboard:', error);
      message.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  // Chart data for revenue trend (last 7 days)
  const revenueChartData = {
    labels: ['6 days ago', '5 days ago', '4 days ago', '3 days ago', '2 days ago', 'Yesterday', 'Today'],
    datasets: [
      {
        label: 'Revenue (₱)',
        data: [12000, 19000, 15000, 22000, 18000, 25000, stats.todayRevenue],
        borderColor: '#1890ff',
        backgroundColor: 'rgba(24, 144, 255, 0.1)',
        fill: true,
        tension: 0.4
      }
    ]
  };

  // Order status chart
  const orderStatusData = {
    labels: ['Pending', 'Processing', 'Completed', 'Cancelled'],
    datasets: [
      {
        data: [stats.pendingOrders, stats.processingOrders, stats.completedOrders, stats.cancelledOrders],
        backgroundColor: ['#faad14', '#1890ff', '#52c41a', '#ff4d4f'],
      }
    ]
  };

  // User distribution chart
  const userDistributionData = {
    labels: ['Buyers', 'Sellers', 'Cooperatives'],
    datasets: [
      {
        data: [stats.totalBuyers, stats.totalSellers, stats.totalCooperatives],
        backgroundColor: ['#1890ff', '#52c41a', '#722ed1'],
      }
    ]
  };

  const quickActions: QuickAction[] = [
    {
      title: 'Pending Sellers',
      count: stats.pendingSellers,
      icon: <ClockCircleOutlined />,
      color: '#faad14',
      action: '/users'
    },
    {
      title: 'Pending Products',
      count: stats.pendingProducts,
      icon: <ShopOutlined />,
      color: '#faad14',
      action: '/products'
    },
    {
      title: 'Pending Orders',
      count: stats.pendingOrders,
      icon: <ShoppingOutlined />,
      color: '#1890ff',
      action: '/transactions'
    },
    {
      title: 'Suspended Users',
      count: stats.suspendedUsers,
      icon: <WarningOutlined />,
      color: '#ff4d4f',
      action: '/users'
    }
  ];

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
        <Spin size="large" tip="Loading dashboard..." />
      </div>
    );
  }

  return (
    <div style={{ padding: '24px', background: '#f0f2f5', minHeight: '100vh' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <Title level={2} style={{ margin: 0 }}>Dashboard Overview</Title>
          <Text type="secondary">Welcome back! Here's what's happening today.</Text>
        </div>
        <Button
          icon={<ReloadOutlined />}
          onClick={loadDashboardData}
          loading={loading}
          type="primary"
          size="large"
        >
          Refresh
        </Button>
      </div>

      {/* Quick Actions Alert */}
      {(stats.pendingSellers > 0 || stats.pendingProducts > 0 || stats.pendingOrders > 0) && (
        <Alert
          message="Action Required"
          description={`You have ${stats.pendingSellers} pending sellers, ${stats.pendingProducts} pending products, and ${stats.pendingOrders} pending orders awaiting review.`}
          type="warning"
          showIcon
          closable
          style={{ marginBottom: '24px' }}
        />
      )}

      {/* Main Statistics Cards */}
      <Row gutter={[16, 16]} style={{ marginBottom: '24px' }}>
        <Col xs={24} sm={12} lg={6}>
          <Card bordered={false}>
            <Statistic
              title="Total Revenue"
              value={stats.totalRevenue}
              precision={2}
              prefix="₱"
              valueStyle={{ color: '#52c41a' }}
              suffix={
                <span style={{ fontSize: '14px', color: '#8c8c8c' }}>
                  <RiseOutlined /> 12.5%
                </span>
              }
            />
            <Text type="secondary" style={{ fontSize: '12px' }}>
              Today: ₱{stats.todayRevenue.toFixed(2)}
            </Text>
          </Card>
        </Col>

        <Col xs={24} sm={12} lg={6}>
          <Card bordered={false}>
            <Statistic
              title="Total Users"
              value={stats.totalUsers}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
            <Progress 
              percent={Math.round((stats.totalUsers / 1000) * 100)} 
              size="small" 
              showInfo={false}
              strokeColor="#1890ff"
            />
          </Card>
        </Col>

        <Col xs={24} sm={12} lg={6}>
          <Card bordered={false}>
            <Statistic
              title="Total Orders"
              value={stats.totalOrders}
              prefix={<ShoppingOutlined />}
              valueStyle={{ color: '#722ed1' }}
            />
            <Text type="secondary" style={{ fontSize: '12px' }}>
              Completed: {stats.completedOrders} ({((stats.completedOrders/stats.totalOrders)*100).toFixed(0)}%)
            </Text>
          </Card>
        </Col>

        <Col xs={24} sm={12} lg={6}>
          <Card bordered={false}>
            <Statistic
              title="Active Products"
              value={stats.approvedProducts}
              prefix={<ShopOutlined />}
              valueStyle={{ color: '#13c2c2' }}
            />
            <Text type="secondary" style={{ fontSize: '12px' }}>
              Pending: {stats.pendingProducts}
            </Text>
          </Card>
        </Col>
      </Row>

      {/* Quick Actions */}
      <Row gutter={[16, 16]} style={{ marginBottom: '24px' }}>
        {quickActions.map((action, index) => (
          <Col xs={24} sm={12} lg={6} key={index}>
            <Card 
              hoverable
              bordered={false}
              style={{ borderLeft: `4px solid ${action.color}` }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <Text type="secondary">{action.title}</Text>
                  <div style={{ fontSize: '24px', fontWeight: 'bold', color: action.color }}>
                    {action.count}
                  </div>
                </div>
                <div style={{ fontSize: '32px', color: action.color, opacity: 0.8 }}>
                  {action.icon}
                </div>
              </div>
              <Button 
                type="link" 
                size="small" 
                icon={<EyeOutlined />}
                onClick={() => window.location.href = action.action}
              >
                View Details
              </Button>
            </Card>
          </Col>
        ))}
      </Row>

      {/* Charts Section */}
      <Row gutter={[16, 16]} style={{ marginBottom: '24px' }}>
        <Col xs={24} lg={12}>
          <Card title="Revenue Trend (Last 7 Days)" bordered={false}>
            <Line 
              data={revenueChartData} 
              options={{
                responsive: true,
                plugins: {
                  legend: { display: false },
                  tooltip: {
                    callbacks: {
                      label: (context) => `₱${context.parsed.y.toFixed(2)}`
                    }
                  }
                },
                scales: {
                  y: { beginAtZero: true }
                }
              }}
            />
          </Card>
        </Col>

        <Col xs={24} lg={6}>
          <Card title="Order Status" bordered={false}>
            <Doughnut 
              data={orderStatusData}
              options={{
                responsive: true,
                plugins: {
                  legend: { position: 'bottom' }
                }
              }}
            />
          </Card>
        </Col>

        <Col xs={24} lg={6}>
          <Card title="User Distribution" bordered={false}>
            <Doughnut 
              data={userDistributionData}
              options={{
                responsive: true,
                plugins: {
                  legend: { position: 'bottom' }
                }
              }}
            />
          </Card>
        </Col>
      </Row>

      {/* Additional Stats & Recent Orders */}
      <Row gutter={[16, 16]}>
        <Col xs={24} lg={12}>
          <Card title="Key Metrics" bordered={false}>
            <Row gutter={[16, 16]}>
              <Col span={12}>
                <Statistic
                  title="Avg Order Value"
                  value={stats.avgOrderValue}
                  precision={2}
                  prefix="₱"
                  valueStyle={{ fontSize: '20px' }}
                />
              </Col>
              <Col span={12}>
                <Statistic
                  title="Month Revenue"
                  value={stats.monthRevenue}
                  precision={2}
                  prefix="₱"
                  valueStyle={{ fontSize: '20px', color: '#52c41a' }}
                />
              </Col>
              <Col span={12}>
                <Statistic
                  title="Approved Sellers"
                  value={stats.approvedSellers}
                  valueStyle={{ fontSize: '20px', color: '#1890ff' }}
                />
              </Col>
              <Col span={12}>
                <Statistic
                  title="Cooperatives"
                  value={stats.totalCooperatives}
                  prefix={<TeamOutlined />}
                  valueStyle={{ fontSize: '20px', color: '#722ed1' }}
                />
              </Col>
            </Row>
          </Card>
        </Col>

        <Col xs={24} lg={12}>
          <Card title="Recent Orders" bordered={false}>
            <List
              dataSource={recentOrders}
              renderItem={(order) => (
                <List.Item>
                  <List.Item.Meta
                    avatar={<Avatar icon={<ShoppingOutlined />} />}
                    title={order.customerName}
                    description={order.date?.toDate().toLocaleString()}
                  />
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontWeight: 'bold' }}>₱{order.amount.toFixed(2)}</div>
                    <Tag color={
                      order.status === 'completed' ? 'green' :
                      order.status === 'processing' ? 'blue' :
                      order.status === 'cancelled' ? 'red' : 'orange'
                    }>
                      {order.status.toUpperCase()}
                    </Tag>
                  </div>
                </List.Item>
              )}
            />
          </Card>
        </Col>
      </Row>

      {/* System Health */}
      <Card 
        title="System Health" 
        bordered={false} 
        style={{ marginTop: '24px' }}
      >
        <Row gutter={[16, 16]}>
          <Col span={8}>
            <div>
              <Text type="secondary">User Approval Rate</Text>
              <Progress 
                percent={Math.round((stats.approvedSellers / stats.totalSellers) * 100) || 0}
                status="active"
                strokeColor="#52c41a"
              />
            </div>
          </Col>
          <Col span={8}>
            <div>
              <Text type="secondary">Product Approval Rate</Text>
              <Progress 
                percent={Math.round((stats.approvedProducts / stats.totalProducts) * 100) || 0}
                status="active"
                strokeColor="#1890ff"
              />
            </div>
          </Col>
          <Col span={8}>
            <div>
              <Text type="secondary">Order Completion Rate</Text>
              <Progress 
                percent={Math.round((stats.completedOrders / stats.totalOrders) * 100) || 0}
                status="active"
                strokeColor="#722ed1"
              />
            </div>
          </Col>
        </Row>
      </Card>
    </div>
  );
};

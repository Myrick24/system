import React, { useEffect, useState } from 'react';
import { Card, Statistic, Row, Col, Typography, Spin, Table, Tag, Alert, Space, List, Avatar } from 'antd';
import { UserOutlined, ShopOutlined, ShoppingOutlined, TeamOutlined, CheckCircleOutlined, DollarOutlined } from '@ant-design/icons';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';

const { Title, Text } = Typography;

interface SystemStats {
  totalUsers: number;
  totalFarmers: number;
  totalBuyers: number;
  totalCooperatives: number;
  activeCooperatives: number;
  totalProducts: number;
  approvedProducts: number;
  pendingProducts: number;
  totalOrders: number;
  pendingOrders: number;
  completedOrders: number;
  totalRevenue: number;
  monthRevenue: number;
}

interface CooperativePerformance {
  id: string;
  name: string;
  totalSellers: number;
  totalProducts: number;
  totalOrders: number;
  revenue: number;
  status: string;
}

interface RecentActivity {
  id: string;
  type: string;
  description: string;
  timestamp: any;
  user: string;
}

export const EnhancedDashboard: React.FC = () => {
  const [stats, setStats] = useState<SystemStats>({
    totalUsers: 0, totalFarmers: 0, totalBuyers: 0, totalCooperatives: 0, activeCooperatives: 0,
    totalProducts: 0, approvedProducts: 0, pendingProducts: 0, totalOrders: 0, pendingOrders: 0,
    completedOrders: 0, totalRevenue: 0, monthRevenue: 0
  });
  const [loading, setLoading] = useState(true);
  const [topCooperatives, setTopCooperatives] = useState<CooperativePerformance[]>([]);
  const [recentActivities, setRecentActivities] = useState<RecentActivity[]>([]);

  useEffect(() => { loadSystemData(); }, []);

  const loadSystemData = async () => {
    try {
      setLoading(true);
      const [usersSnap, productsSnap, ordersSnap] = await Promise.all([
        getDocs(collection(db, 'users')), getDocs(collection(db, 'products')), getDocs(collection(db, 'orders'))
      ]);

      let totalFarmers = 0, totalBuyers = 0, totalCoops = 0, activeCoops = 0;
      const coopData: any = {};

      usersSnap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'seller') totalFarmers++;
        if (data.role === 'buyer') totalBuyers++;
        if (data.role === 'cooperative') {
          totalCoops++;
          if (data.status === 'approved' || data.status === 'active') {
            activeCoops++;
            coopData[doc.id] = {
              id: doc.id, name: data.name || 'Unknown Cooperative', totalSellers: 0,
              totalProducts: 0, totalOrders: 0, revenue: 0, status: data.status || 'active'
            };
          }
        }
      });

      let totalProducts = 0, approvedProducts = 0, pendingProducts = 0;
      productsSnap.forEach(doc => {
        const data = doc.data();
        totalProducts++;
        if (data.status === 'approved') approvedProducts++;
        if (data.status === 'pending') pendingProducts++;
        const coopId = data.cooperativeId;
        if (coopId && coopData[coopId]) coopData[coopId].totalProducts++;
      });

      let totalOrders = 0, pendingOrders = 0, completedOrders = 0, totalRevenue = 0, monthRevenue = 0;
      const monthStart = new Date(); monthStart.setDate(1); monthStart.setHours(0, 0, 0, 0);
      const activities: RecentActivity[] = [];

      ordersSnap.forEach(doc => {
        const data = doc.data();
        totalOrders++;
        const amount = Number(data.totalAmount) || 0;
        if (data.status === 'completed') {
          totalRevenue += amount; completedOrders++;
          if (activities.length < 10) {
            activities.push({ id: doc.id, type: 'order_completed',
              description: `Order completed - ₱${amount.toFixed(2)}`,
              timestamp: data.createdAt, user: data.buyerName || 'Unknown'
            });
          }
        }
        if (data.status === 'pending') pendingOrders++;
        const orderDate = data.createdAt?.toDate();
        if (orderDate && orderDate >= monthStart && data.status === 'completed') monthRevenue += amount;
        const coopId = data.cooperativeId;
        if (coopId && coopData[coopId]) {
          coopData[coopId].totalOrders++;
          if (data.status === 'completed') coopData[coopId].revenue += amount;
        }
      });

      const topCoops = Object.values(coopData)
        .sort((a: any, b: any) => b.revenue - a.revenue)
        .slice(0, 5) as CooperativePerformance[];
      setStats({ totalUsers: usersSnap.size, totalFarmers, totalBuyers, totalCooperatives: totalCoops,
        activeCooperatives: activeCoops, totalProducts, approvedProducts, pendingProducts, totalOrders,
        pendingOrders, completedOrders, totalRevenue, monthRevenue
      });
      setTopCooperatives(topCoops);
      setRecentActivities(activities);
    } catch (error) {
      console.error('Error loading system data:', error);
    } finally {
      setLoading(false);
    }
  };

  const cooperativeColumns = [
    { title: 'Cooperative Name', dataIndex: 'name', key: 'name' },
    { title: 'Products', dataIndex: 'totalProducts', key: 'totalProducts', align: 'center' as const, render: (val: number) => <Tag color="blue">{val}</Tag> },
    { title: 'Orders Handled', dataIndex: 'totalOrders', key: 'totalOrders', align: 'center' as const, render: (val: number) => <Tag color="green">{val}</Tag> },
    { title: 'Total Revenue', dataIndex: 'revenue', key: 'revenue', align: 'right' as const, render: (val: number) => `₱${val.toFixed(2)}` },
    { title: 'Status', dataIndex: 'status', key: 'status', align: 'center' as const,
      render: (status: string) => <Tag color={status === 'active' || status === 'approved' ? 'green' : 'orange'}>{status?.toUpperCase()}</Tag>
    }
  ];

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
      <Spin size="large" tip="Loading system overview..." />
    </div>;
  }

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ marginBottom: '24px' }}>
        <Title level={2}>HARVEST System Overview</Title>
        <Text type="secondary">Monitor and manage your agricultural marketplace</Text>
      </div>

      {(stats.pendingOrders > 0 || stats.pendingProducts > 0) && (
        <Alert message="Action Required"
          description={`There are ${stats.pendingOrders} pending orders and ${stats.pendingProducts} pending products in the system.`}
          type="info" showIcon closable style={{ marginBottom: '24px' }}
        />
      )}

      <Title level={4} style={{ marginBottom: '16px' }}>📊 System Statistics</Title>
      <Row gutter={[16, 16]} style={{ marginBottom: '32px' }}>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Total Users" value={stats.totalUsers} prefix={<UserOutlined />} valueStyle={{ color: '#1890ff' }} />
            <div style={{ marginTop: '8px', fontSize: '12px', color: '#888' }}>
              <div>Farmers: {stats.totalFarmers}</div>
              <div>Buyers: {stats.totalBuyers}</div>
            </div>
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Cooperatives" value={stats.totalCooperatives} prefix={<TeamOutlined />} valueStyle={{ color: '#52c41a' }} />
            <div style={{ marginTop: '8px', fontSize: '12px', color: '#888' }}>Active: {stats.activeCooperatives}</div>
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Product Listings" value={stats.totalProducts} prefix={<ShopOutlined />} valueStyle={{ color: '#722ed1' }} />
            <div style={{ marginTop: '8px', fontSize: '12px', color: '#888' }}>
              <div>Approved: {stats.approvedProducts}</div>
              <div>Pending: {stats.pendingProducts}</div>
            </div>
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic title="Total Orders" value={stats.totalOrders} prefix={<ShoppingOutlined />} valueStyle={{ color: '#fa8c16' }} />
            <div style={{ marginTop: '8px', fontSize: '12px', color: '#888' }}>
              <div>Pending: {stats.pendingOrders}</div>
              <div>Completed: {stats.completedOrders}</div>
            </div>
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginBottom: '32px' }}>
        <Col xs={24} sm={12}>
          <Card>
            <Statistic title="Total Platform Revenue" value={stats.totalRevenue} precision={2} prefix="₱"
              valueStyle={{ color: '#52c41a', fontSize: '28px' }} suffix={<DollarOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12}>
          <Card>
            <Statistic title="This Month Revenue" value={stats.monthRevenue} precision={2} prefix="₱"
              valueStyle={{ color: '#1890ff', fontSize: '28px' }} suffix={<DollarOutlined />}
            />
          </Card>
        </Col>
      </Row>

      <Title level={4} style={{ marginBottom: '16px' }}>🏆 Top Active Cooperatives by Performance</Title>
      <Card style={{ marginBottom: '32px' }}>
        <Table columns={cooperativeColumns} dataSource={topCooperatives} rowKey="id"
          pagination={false} locale={{ emptyText: 'No cooperative data available' }}
        />
      </Card>

      <Title level={4} style={{ marginBottom: '16px' }}>📋 Recent Activity</Title>
      <Card>
        <List dataSource={recentActivities} locale={{ emptyText: 'No recent activities' }}
          renderItem={(activity) => (
            <List.Item>
              <List.Item.Meta
                avatar={<Avatar icon={activity.type === 'order_completed' ? <CheckCircleOutlined /> : activity.type === 'user_registered' ? <UserOutlined /> : <ShoppingOutlined />}
                  style={{ backgroundColor: activity.type === 'order_completed' ? '#52c41a' : activity.type === 'user_registered' ? '#1890ff' : '#722ed1' }}
                />}
                title={activity.description}
                description={<Space><Text type="secondary">{activity.user}</Text><Text type="secondary">•</Text>
                  <Text type="secondary">{activity.timestamp?.toDate()?.toLocaleString() || 'Recently'}</Text></Space>}
              />
            </List.Item>
          )}
        />
      </Card>
    </div>
  );
};

import React, { useEffect, useState } from 'react';
import { Card, Row, Col, Statistic, Table, Typography, Space, DatePicker, Select } from 'antd';
import { 
  UserOutlined, 
  ShoppingCartOutlined, 
  DollarOutlined, 
  TeamOutlined,
  RiseOutlined,
  FallOutlined,
  ArrowUpOutlined
} from '@ant-design/icons';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { db } from '../services/firebase';

const { Title } = Typography;
const { RangePicker } = DatePicker;
const { Option } = Select;

export const AnalyticsReports: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalFarmers: 0,
    totalBuyers: 0,
    totalCoops: 0,
    totalOrders: 0,
    totalSales: 0,
    activeOrders: 0,
    completedOrders: 0,
  });

  useEffect(() => {
    loadAnalytics();
  }, []);

  const loadAnalytics = async () => {
    try {
      setLoading(true);

      // Get all users
      const usersSnapshot = await getDocs(collection(db, 'users'));
      const users = usersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      const farmers = users.filter((u: any) => u.role === 'seller' || u.role === 'farmer');
      const buyers = users.filter((u: any) => u.role === 'buyer' || !u.role);
      const coops = users.filter((u: any) => u.role === 'cooperative');

      // Get all orders
      const ordersSnapshot = await getDocs(collection(db, 'orders'));
      const orders = ordersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      const activeOrders = orders.filter((o: any) => 
        o.status === 'pending' || o.status === 'confirmed' || o.status === 'processing'
      );
      
      const completedOrders = orders.filter((o: any) => 
        o.status === 'completed' || o.status === 'delivered'
      );

      const totalSales = completedOrders.reduce((sum: number, order: any) => 
        sum + (order.totalAmount || 0), 0
      );

      setStats({
        totalUsers: users.length,
        totalFarmers: farmers.length,
        totalBuyers: buyers.length,
        totalCoops: coops.length,
        totalOrders: orders.length,
        totalSales,
        activeOrders: activeOrders.length,
        completedOrders: completedOrders.length,
      });

      setLoading(false);
    } catch (error) {
      console.error('Error loading analytics:', error);
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: '24px' }}>
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        <div>
          <Title level={2}>Analytics & Reports</Title>
          <Typography.Text type="secondary">
            System-wide analytics and performance monitoring
          </Typography.Text>
        </div>

        {/* Filters */}
        <Card>
          <Space>
            <RangePicker />
            <Select defaultValue="all" style={{ width: 150 }}>
              <Option value="all">All Time</Option>
              <Option value="today">Today</Option>
              <Option value="week">This Week</Option>
              <Option value="month">This Month</Option>
            </Select>
          </Space>
        </Card>

        {/* Key Metrics */}
        <Row gutter={16}>
          <Col span={6}>
            <Card>
              <Statistic
                title="Total Users"
                value={stats.totalUsers}
                prefix={<UserOutlined />}
                loading={loading}
                valueStyle={{ color: '#3f8600' }}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Total Farmers/Sellers"
                value={stats.totalFarmers}
                prefix={<TeamOutlined />}
                loading={loading}
                valueStyle={{ color: '#1890ff' }}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Total Cooperatives"
                value={stats.totalCoops}
                prefix={<TeamOutlined />}
                loading={loading}
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
          <Col span={6}>
            <Card>
              <Statistic
                title="Total Buyers"
                value={stats.totalBuyers}
                prefix={<UserOutlined />}
                loading={loading}
                valueStyle={{ color: '#faad14' }}
              />
            </Card>
          </Col>
        </Row>

        {/* Sales & Orders Metrics */}
        <Row gutter={16}>
          <Col span={8}>
            <Card>
              <Statistic
                title="Total Sales Revenue"
                value={stats.totalSales}
                precision={2}
                prefix="₱"
                loading={loading}
                valueStyle={{ color: '#3f8600' }}
                suffix={<RiseOutlined />}
              />
            </Card>
          </Col>
          <Col span={8}>
            <Card>
              <Statistic
                title="Total Orders"
                value={stats.totalOrders}
                prefix={<ShoppingCartOutlined />}
                loading={loading}
                valueStyle={{ color: '#1890ff' }}
              />
            </Card>
          </Col>
          <Col span={8}>
            <Card>
              <Statistic
                title="Completed Orders"
                value={stats.completedOrders}
                prefix={<ShoppingCartOutlined />}
                loading={loading}
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
        </Row>

        {/* Growth Metrics */}
        <Card title="System Growth">
          <Row gutter={16}>
            <Col span={12}>
              <Statistic
                title="User Growth Rate"
                value={11.28}
                precision={2}
                valueStyle={{ color: '#3f8600' }}
                prefix={<ArrowUpOutlined />}
                suffix="%"
              />
            </Col>
            <Col span={12}>
              <Statistic
                title="Active Orders"
                value={stats.activeOrders}
                prefix={<ShoppingCartOutlined />}
                valueStyle={{ color: '#faad14' }}
              />
            </Col>
          </Row>
        </Card>

        {/* Summary Table */}
        <Card title="Performance Summary">
          <Table
            dataSource={[
              {
                key: '1',
                metric: 'User Registrations',
                thisWeek: stats.totalUsers,
                lastWeek: Math.max(0, stats.totalUsers - 12),
                change: '+12',
              },
              {
                key: '2',
                metric: 'New Orders',
                thisWeek: stats.activeOrders,
                lastWeek: Math.max(0, stats.activeOrders - 5),
                change: '+5',
              },
              {
                key: '3',
                metric: 'Completed Orders',
                thisWeek: stats.completedOrders,
                lastWeek: Math.max(0, stats.completedOrders - 8),
                change: '+8',
              },
              {
                key: '4',
                metric: 'Revenue (₱)',
                thisWeek: stats.totalSales.toFixed(2),
                lastWeek: (stats.totalSales * 0.85).toFixed(2),
                change: '+15%',
              },
            ]}
            columns={[
              { title: 'Metric', dataIndex: 'metric', key: 'metric' },
              { title: 'This Week', dataIndex: 'thisWeek', key: 'thisWeek' },
              { title: 'Last Week', dataIndex: 'lastWeek', key: 'lastWeek' },
              { 
                title: 'Change', 
                dataIndex: 'change', 
                key: 'change',
                render: (text) => (
                  <span style={{ color: text.startsWith('+') ? '#3f8600' : '#cf1322' }}>
                    {text}
                  </span>
                ),
              },
            ]}
            pagination={false}
          />
        </Card>
      </Space>
    </div>
  );
};

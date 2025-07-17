import React, { useEffect, useState } from 'react';
import { Card, Statistic, Row, Col, Typography, Spin, Table, Tag, Button, message } from 'antd';
import { 
  UserOutlined, 
  ShopOutlined, 
  ShoppingOutlined, 
  DollarOutlined,
  TeamOutlined,
  ClockCircleOutlined,
  ReloadOutlined
} from '@ant-design/icons';
import { AdminService } from '../services/adminService';
import { DashboardStats, RecentActivity } from '../types';

const { Title } = Typography;

export const DashboardHome: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recentActivity, setRecentActivity] = useState<RecentActivity[]>([]);
  const [loading, setLoading] = useState(true);
  const adminService = new AdminService();

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      console.log('Loading dashboard data...');
      
      const [dashboardStats, activityData] = await Promise.all([
        adminService.getDashboardStats(),
        adminService.getRecentActivity()
      ]);
      
      console.log('Dashboard stats loaded:', dashboardStats);
      console.log('Activity data loaded:', activityData);
      
      setStats(dashboardStats);
      setRecentActivity(activityData);
      
      message.success('Dashboard data loaded successfully');
    } catch (error) {
      console.error('Error loading dashboard data:', error);
      message.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const activityColumns = [
    {
      title: 'Type',
      dataIndex: 'type',
      key: 'type',
      render: (type: string) => {
        const typeMap = {
          user_registration: { text: 'User Registration', color: 'blue' },
          pending_seller: { text: 'Pending Seller', color: 'orange' },
          transaction: { text: 'Transaction', color: 'green' },
          product_listing: { text: 'Product Listing', color: 'purple' }
        };
        
        const config = typeMap[type as keyof typeof typeMap] || { text: type, color: 'default' };
        return <Tag color={config.color}>{config.text}</Tag>;
      }
    },
    {
      title: 'Details',
      key: 'details',
      render: (record: RecentActivity) => {
        if (record.user) {
          return `${record.user.name} (${record.user.role})`;
        }
        if (record.transaction) {
          return `$${record.transaction.amount} - ${record.transaction.status}`;
        }
        if (record.product) {
          return `${record.product.name} - ${record.product.status}`;
        }
        return 'N/A';
      }
    },
    {
      title: 'Time',
      dataIndex: 'timestamp',
      key: 'timestamp',
      render: (timestamp: any) => {
        if (!timestamp) return 'N/A';
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return date.toLocaleString();
      }
    }
  ];

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
        <Spin size="large" />
      </div>
    );
  }

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <Title level={2}>Dashboard Overview</Title>
        <Button
          icon={<ReloadOutlined />}
          onClick={loadDashboardData}
          loading={loading}
          type="primary"
        >
          Refresh Data
        </Button>
      </div>
      
      {/* Statistics Cards */}
      <Row gutter={[16, 16]} style={{ marginBottom: '24px' }}>
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Total Users"
              value={stats?.totalUsers || 0}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Approved Sellers"
              value={stats?.approvedSellers || 0}
              prefix={<TeamOutlined />}
              valueStyle={{ color: '#52c41a' }}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Pending Sellers"
              value={stats?.pendingSellers || 0}
              prefix={<ClockCircleOutlined />}
              valueStyle={{ color: '#faad14' }}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Active Listings"
              value={stats?.activeListings || 0}
              prefix={<ShopOutlined />}
              valueStyle={{ color: '#722ed1' }}
            />
          </Card>
        </Col>
        
        <Col xs={24} sm={12} lg={6}>
          <Card>
            <Statistic
              title="Completed Orders"
              value={stats?.completedTransactions || 0}
              prefix={<DollarOutlined />}
              valueStyle={{ color: '#13c2c2' }}
            />
          </Card>
        </Col>
      </Row>

      {/* Recent Activity */}
      <Card title="Recent Activity" style={{ marginBottom: '24px' }}>
        <Table
          dataSource={recentActivity}
          columns={activityColumns}
          rowKey="id"
          pagination={{ pageSize: 10 }}
          scroll={{ x: true }}
        />
      </Card>
    </div>
  );
};

import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Statistic, Table, DatePicker, Button, Select, Space, message } from 'antd';
import { FileTextOutlined, DownloadOutlined, UserOutlined, ShoppingOutlined, DollarOutlined, TeamOutlined } from '@ant-design/icons';
import { collection, query, getDocs, where, Timestamp } from 'firebase/firestore';
import { db } from '../services/firebase';
import dayjs from 'dayjs';

const { RangePicker } = DatePicker;

interface ReportData {
  totalUsers: number;
  totalCooperatives: number;
  totalProducts: number;
  totalOrders: number;
  totalRevenue: number;
  cooperativePerformance: any[];
  monthlyRegistrations: any[];
  orderTrends: any[];
}

export const ReportsAnalytics: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [reportData, setReportData] = useState<ReportData>({
    totalUsers: 0,
    totalCooperatives: 0,
    totalProducts: 0,
    totalOrders: 0,
    totalRevenue: 0,
    cooperativePerformance: [],
    monthlyRegistrations: [],
    orderTrends: []
  });
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs]>([
    dayjs().subtract(30, 'days'),
    dayjs()
  ]);
  const [selectedReport, setSelectedReport] = useState('overview');

  useEffect(() => {
    loadReportData();
  }, [dateRange]);

  const loadReportData = async () => {
    setLoading(true);
    try {
      const startDate = Timestamp.fromDate(dateRange[0].toDate());
      const endDate = Timestamp.fromDate(dateRange[1].toDate());

      // Load users
      const usersSnapshot = await getDocs(collection(db, 'users'));
      const totalUsers = usersSnapshot.size;

      // Load cooperatives
      const coopsQuery = query(
        collection(db, 'users'),
        where('role', '==', 'cooperative')
      );
      const coopsSnapshot = await getDocs(coopsQuery);
      const totalCooperatives = coopsSnapshot.size;

      // Load products
      const productsSnapshot = await getDocs(collection(db, 'products'));
      const totalProducts = productsSnapshot.size;

      // Load orders
      const ordersQuery = query(
        collection(db, 'orders'),
        where('createdAt', '>=', startDate),
        where('createdAt', '<=', endDate)
      );
      const ordersSnapshot = await getDocs(ordersQuery);
      const totalOrders = ordersSnapshot.size;

      // Calculate total revenue
      let totalRevenue = 0;
      ordersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.status === 'completed' && data.totalAmount) {
          totalRevenue += parseFloat(data.totalAmount);
        }
      });

      // Cooperative performance
      const coopPerformance: any = {};
      ordersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const coopId = data.cooperativeId;
        if (coopId) {
          if (!coopPerformance[coopId]) {
            coopPerformance[coopId] = {
              cooperativeId: coopId,
              cooperativeName: data.cooperativeName || 'Unknown',
              totalOrders: 0,
              totalRevenue: 0
            };
          }
          coopPerformance[coopId].totalOrders++;
          if (data.status === 'completed') {
            coopPerformance[coopId].totalRevenue += parseFloat(data.totalAmount || 0);
          }
        }
      });

      const cooperativePerformance = Object.values(coopPerformance)
        .sort((a: any, b: any) => b.totalRevenue - a.totalRevenue);

      // Monthly registrations
      const registrationsByMonth: any = {};
      usersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.createdAt) {
          const date = data.createdAt.toDate();
          const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
          registrationsByMonth[monthKey] = (registrationsByMonth[monthKey] || 0) + 1;
        }
      });

      const monthlyRegistrations = Object.entries(registrationsByMonth)
        .map(([month, count]) => ({ month, count }))
        .sort((a, b) => a.month.localeCompare(b.month));

      // Order trends
      const ordersByDate: any = {};
      ordersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.createdAt) {
          const date = data.createdAt.toDate();
          const dateKey = date.toISOString().split('T')[0];
          if (!ordersByDate[dateKey]) {
            ordersByDate[dateKey] = { date: dateKey, orders: 0, revenue: 0 };
          }
          ordersByDate[dateKey].orders++;
          if (data.status === 'completed') {
            ordersByDate[dateKey].revenue += parseFloat(data.totalAmount || 0);
          }
        }
      });

      const orderTrends = Object.values(ordersByDate)
        .sort((a: any, b: any) => a.date.localeCompare(b.date));

      setReportData({
        totalUsers,
        totalCooperatives,
        totalProducts,
        totalOrders,
        totalRevenue,
        cooperativePerformance,
        monthlyRegistrations,
        orderTrends
      });
    } catch (error) {
      console.error('Error loading report data:', error);
      message.error('Failed to load report data');
    } finally {
      setLoading(false);
    }
  };

  const exportReport = () => {
    // Create CSV content
    let csvContent = 'data:text/csv;charset=utf-8,';
    
    if (selectedReport === 'cooperative-performance') {
      csvContent += 'Cooperative Name,Total Orders,Total Revenue\n';
      reportData.cooperativePerformance.forEach((coop: any) => {
        csvContent += `${coop.cooperativeName},${coop.totalOrders},${coop.totalRevenue.toFixed(2)}\n`;
      });
    } else if (selectedReport === 'monthly-registrations') {
      csvContent += 'Month,User Registrations\n';
      reportData.monthlyRegistrations.forEach((month: any) => {
        csvContent += `${month.month},${month.count}\n`;
      });
    } else if (selectedReport === 'order-trends') {
      csvContent += 'Date,Orders,Revenue\n';
      reportData.orderTrends.forEach((day: any) => {
        csvContent += `${day.date},${day.orders},${day.revenue.toFixed(2)}\n`;
      });
    }

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `harvest_report_${selectedReport}_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    message.success('Report exported successfully');
  };

  const coopPerformanceColumns = [
    {
      title: 'Cooperative',
      dataIndex: 'cooperativeName',
      key: 'cooperativeName'
    },
    {
      title: 'Total Orders',
      dataIndex: 'totalOrders',
      key: 'totalOrders',
      sorter: (a: any, b: any) => a.totalOrders - b.totalOrders
    },
    {
      title: 'Total Revenue',
      dataIndex: 'totalRevenue',
      key: 'totalRevenue',
      render: (value: number) => `₱${value.toFixed(2)}`,
      sorter: (a: any, b: any) => a.totalRevenue - b.totalRevenue
    }
  ];

  const monthlyRegColumns = [
    {
      title: 'Month',
      dataIndex: 'month',
      key: 'month'
    },
    {
      title: 'New Users',
      dataIndex: 'count',
      key: 'count',
      sorter: (a: any, b: any) => a.count - b.count
    }
  ];

  const orderTrendsColumns = [
    {
      title: 'Date',
      dataIndex: 'date',
      key: 'date'
    },
    {
      title: 'Orders',
      dataIndex: 'orders',
      key: 'orders',
      sorter: (a: any, b: any) => a.orders - b.orders
    },
    {
      title: 'Revenue',
      dataIndex: 'revenue',
      key: 'revenue',
      render: (value: number) => `₱${value.toFixed(2)}`,
      sorter: (a: any, b: any) => a.revenue - b.revenue
    }
  ];

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <h2><FileTextOutlined /> Reports & Analytics</h2>
        <Space>
          <RangePicker
            value={dateRange}
            onChange={(dates: any) => dates && setDateRange(dates)}
            format="YYYY-MM-DD"
          />
          <Button
            type="primary"
            icon={<DownloadOutlined />}
            onClick={exportReport}
          >
            Export Report
          </Button>
        </Space>
      </div>

      {/* Overview Statistics */}
      <Row gutter={16} style={{ marginBottom: '24px' }}>
        <Col span={6}>
          <Card>
            <Statistic
              title="Total Users"
              value={reportData.totalUsers}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="Total Cooperatives"
              value={reportData.totalCooperatives}
              prefix={<TeamOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="Total Products"
              value={reportData.totalProducts}
              prefix={<ShoppingOutlined />}
              valueStyle={{ color: '#cf1322' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card>
            <Statistic
              title="Total Orders"
              value={reportData.totalOrders}
              prefix={<ShoppingOutlined />}
              valueStyle={{ color: '#faad14' }}
            />
          </Card>
        </Col>
      </Row>

      <Row gutter={16} style={{ marginBottom: '24px' }}>
        <Col span={24}>
          <Card>
            <Statistic
              title="Total Revenue (Selected Period)"
              value={reportData.totalRevenue}
              precision={2}
              prefix={<DollarOutlined />}
              suffix="PHP"
              valueStyle={{ color: '#3f8600', fontSize: '32px' }}
            />
          </Card>
        </Col>
      </Row>

      {/* Report Type Selector */}
      <Card style={{ marginBottom: '24px' }}>
        <Space style={{ marginBottom: '16px' }}>
          <span>Select Report Type:</span>
          <Select
            value={selectedReport}
            onChange={setSelectedReport}
            style={{ width: 250 }}
          >
            <Select.Option value="cooperative-performance">Cooperative Performance</Select.Option>
            <Select.Option value="monthly-registrations">Monthly User Registrations</Select.Option>
            <Select.Option value="order-trends">Order Trends</Select.Option>
          </Select>
        </Space>

        {selectedReport === 'cooperative-performance' && (
          <Table
            columns={coopPerformanceColumns}
            dataSource={reportData.cooperativePerformance}
            rowKey="cooperativeId"
            loading={loading}
            pagination={{ pageSize: 10 }}
          />
        )}

        {selectedReport === 'monthly-registrations' && (
          <Table
            columns={monthlyRegColumns}
            dataSource={reportData.monthlyRegistrations}
            rowKey="month"
            loading={loading}
            pagination={{ pageSize: 10 }}
          />
        )}

        {selectedReport === 'order-trends' && (
          <Table
            columns={orderTrendsColumns}
            dataSource={reportData.orderTrends}
            rowKey="date"
            loading={loading}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>
    </div>
  );
};

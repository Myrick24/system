import React, { useEffect, useState } from 'react';
import { Card, Table, Tag, Typography, Space, Input, Select, DatePicker, Button } from 'antd';
import { 
  SearchOutlined, 
  LockOutlined, 
  UserOutlined,
  WarningOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  ReloadOutlined
} from '@ant-design/icons';
import { collection, getDocs, query, orderBy, limit } from 'firebase/firestore';
import { db } from '../services/firebase';
import type { ColumnsType } from 'antd/es/table';

const { Title } = Typography;
const { RangePicker } = DatePicker;
const { Option } = Select;

interface AuditLog {
  key: string;
  timestamp: string;
  action: string;
  user: string;
  userId: string;
  ipAddress: string;
  status: 'success' | 'failed' | 'warning';
  details: string;
}

export const AuditLogs: React.FC = () => {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchText, setSearchText] = useState('');
  const [filterAction, setFilterAction] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');

  useEffect(() => {
    loadAuditLogs();
  }, []);

  const loadAuditLogs = async () => {
    try {
      setLoading(true);
      
      // Mock data - In production, this would come from a real audit_logs collection
      const mockLogs: AuditLog[] = [
        {
          key: '1',
          timestamp: new Date().toISOString(),
          action: 'User Login',
          user: 'admin@example.com',
          userId: 'admin123',
          ipAddress: '192.168.1.1',
          status: 'success',
          details: 'Successful login from admin panel',
        },
        {
          key: '2',
          timestamp: new Date(Date.now() - 3600000).toISOString(),
          action: 'Cooperative Approved',
          user: 'admin@example.com',
          userId: 'admin123',
          ipAddress: '192.168.1.1',
          status: 'success',
          details: 'Approved cooperative account: Coop123',
        },
        {
          key: '3',
          timestamp: new Date(Date.now() - 7200000).toISOString(),
          action: 'Failed Login Attempt',
          user: 'unknown@example.com',
          userId: 'N/A',
          ipAddress: '10.0.0.5',
          status: 'failed',
          details: 'Invalid credentials',
        },
        {
          key: '4',
          timestamp: new Date(Date.now() - 10800000).toISOString(),
          action: 'User Suspended',
          user: 'admin@example.com',
          userId: 'admin123',
          ipAddress: '192.168.1.1',
          status: 'warning',
          details: 'Suspended user: user456 for policy violation',
        },
        {
          key: '5',
          timestamp: new Date(Date.now() - 14400000).toISOString(),
          action: 'Product Deleted',
          user: 'admin@example.com',
          userId: 'admin123',
          ipAddress: '192.168.1.1',
          status: 'success',
          details: 'Deleted inappropriate product listing: prod789',
        },
      ];

      setLogs(mockLogs);
      setLoading(false);
    } catch (error) {
      console.error('Error loading audit logs:', error);
      setLoading(false);
    }
  };

  const getStatusTag = (status: string) => {
    switch (status) {
      case 'success':
        return <Tag icon={<CheckCircleOutlined />} color="success">Success</Tag>;
      case 'failed':
        return <Tag icon={<CloseCircleOutlined />} color="error">Failed</Tag>;
      case 'warning':
        return <Tag icon={<WarningOutlined />} color="warning">Warning</Tag>;
      default:
        return <Tag>{status}</Tag>;
    }
  };

  const getActionIcon = (action: string) => {
    if (action.includes('Login')) return <LockOutlined />;
    if (action.includes('User')) return <UserOutlined />;
    return <WarningOutlined />;
  };

  const columns: ColumnsType<AuditLog> = [
    {
      title: 'Timestamp',
      dataIndex: 'timestamp',
      key: 'timestamp',
      width: 180,
      render: (timestamp: string) => new Date(timestamp).toLocaleString(),
      sorter: (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime(),
    },
    {
      title: 'Action',
      dataIndex: 'action',
      key: 'action',
      render: (action: string) => (
        <Space>
          {getActionIcon(action)}
          {action}
        </Space>
      ),
      filters: [
        { text: 'User Login', value: 'User Login' },
        { text: 'Cooperative Approved', value: 'Cooperative Approved' },
        { text: 'User Suspended', value: 'User Suspended' },
        { text: 'Product Deleted', value: 'Product Deleted' },
      ],
      onFilter: (value, record) => record.action.includes(value as string),
    },
    {
      title: 'User',
      dataIndex: 'user',
      key: 'user',
      render: (user: string, record) => (
        <div>
          <div>{user}</div>
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {record.userId}
          </Typography.Text>
        </div>
      ),
    },
    {
      title: 'IP Address',
      dataIndex: 'ipAddress',
      key: 'ipAddress',
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => getStatusTag(status),
      filters: [
        { text: 'Success', value: 'success' },
        { text: 'Failed', value: 'failed' },
        { text: 'Warning', value: 'warning' },
      ],
      onFilter: (value, record) => record.status === value,
    },
    {
      title: 'Details',
      dataIndex: 'details',
      key: 'details',
      ellipsis: true,
    },
  ];

  return (
    <div style={{ padding: '24px' }}>
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        <div>
          <Title level={2}>Audit Logs</Title>
          <Typography.Text type="secondary">
            Security and authorization monitoring - Track all system activities
          </Typography.Text>
        </div>

        {/* Filters */}
        <Card>
          <Space wrap>
            <Input
              placeholder="Search logs..."
              prefix={<SearchOutlined />}
              style={{ width: 250 }}
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
            />
            <Select 
              defaultValue="all" 
              style={{ width: 150 }}
              onChange={(value) => setFilterAction(value)}
            >
              <Option value="all">All Actions</Option>
              <Option value="login">Login Activities</Option>
              <Option value="user">User Changes</Option>
              <Option value="coop">Cooperative Actions</Option>
            </Select>
            <Select 
              defaultValue="all" 
              style={{ width: 150 }}
              onChange={(value) => setFilterStatus(value)}
            >
              <Option value="all">All Status</Option>
              <Option value="success">Success</Option>
              <Option value="failed">Failed</Option>
              <Option value="warning">Warning</Option>
            </Select>
            <RangePicker />
            <Button 
              icon={<ReloadOutlined />} 
              onClick={loadAuditLogs}
            >
              Refresh
            </Button>
          </Space>
        </Card>

        {/* Logs Table */}
        <Card>
          <Table
            columns={columns}
            dataSource={logs}
            loading={loading}
            pagination={{
              pageSize: 10,
              showSizeChanger: true,
              showTotal: (total) => `Total ${total} logs`,
            }}
          />
        </Card>

        {/* Security Summary */}
        <Card title="Security Summary">
          <Space direction="vertical" style={{ width: '100%' }}>
            <div>
              <Typography.Text strong>Recent Failed Login Attempts: </Typography.Text>
              <Tag color="error">1</Tag>
            </div>
            <div>
              <Typography.Text strong>Suspicious Activities: </Typography.Text>
              <Tag color="warning">0</Tag>
            </div>
            <div>
              <Typography.Text strong>Recent Admin Actions: </Typography.Text>
              <Tag color="success">4</Tag>
            </div>
          </Space>
        </Card>
      </Space>
    </div>
  );
};

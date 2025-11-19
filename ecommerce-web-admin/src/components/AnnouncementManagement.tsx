import React, { useState } from 'react';
import { 
  Card, 
  Button, 
  Form, 
  Input, 
  Select, 
  message, 
  Space, 
  Typography,
  Alert
} from 'antd';
import { 
  BellOutlined, 
  SendOutlined,
  UserOutlined,
  ShopOutlined,
  TeamOutlined,
  GlobalOutlined
} from '@ant-design/icons';
import { db } from '../services/firebase';
import { collection, addDoc, getDocs, query, where, Timestamp } from 'firebase/firestore';

const { Title } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface AnnouncementFormData {
  title: string;
  message: string;
  targetRole: 'all' | 'buyer' | 'seller' | 'cooperative';
}

export const AnnouncementManagement: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  const handleSendAnnouncement = async (values: AnnouncementFormData) => {
    try {
      setLoading(true);
      
      console.log('Sending announcement:', values);

      // Query users based on target role
      let usersQuery;
      if (values.targetRole === 'all') {
        usersQuery = query(collection(db, 'users'));
      } else {
        usersQuery = query(
          collection(db, 'users'),
          where('role', '==', values.targetRole)
        );
      }

      const usersSnapshot = await getDocs(usersQuery);
      
      if (usersSnapshot.empty) {
        message.warning('No users found for the selected audience');
        setLoading(false);
        return;
      }

      // Create notifications for each user
      const notificationPromises = usersSnapshot.docs.map(async (userDoc) => {
        return addDoc(collection(db, 'notifications'), {
          userId: userDoc.id,
          type: 'announcement',
          title: values.title,
          message: values.message,
          body: values.message,
          timestamp: Timestamp.now(),
          read: false,
          isRead: false,
          status: 'unread',
          targetRole: values.targetRole,
          sentBy: 'admin',
          createdAt: Timestamp.now()
        });
      });

      await Promise.all(notificationPromises);

      message.success(
        `📢 Announcement sent to ${usersSnapshot.docs.length} user(s)!`,
        5
      );
      
      form.resetFields();
    } catch (error) {
      console.error('Error sending announcement:', error);
      message.error('Failed to send announcement. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: '900px', margin: '0 auto', padding: '24px' }}>
      <Card
        style={{
          borderRadius: '16px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.08)'
        }}
      >
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          {/* Header */}
          <div style={{ textAlign: 'center', padding: '16px 0' }}>
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: '80px',
                height: '80px',
                borderRadius: '50%',
                backgroundColor: '#1890ff',
                marginBottom: '16px'
              }}
            >
              <BellOutlined style={{ fontSize: '40px', color: 'white' }} />
            </div>
            <Title level={2} style={{ margin: '0 0 8px 0' }}>
              Send Announcement
            </Title>
            <div style={{ color: '#666', fontSize: '14px' }}>
              Broadcast important notifications to app users
            </div>
          </div>

          {/* Info Alert */}
          <Alert
            message="Push Notification System"
            description="Users will receive instant push notifications on their mobile devices. Make sure your message is clear and actionable."
            type="info"
            showIcon
            icon={<BellOutlined />}
          />

          {/* Announcement Form */}
          <Form
            form={form}
            layout="vertical"
            onFinish={handleSendAnnouncement}
            size="large"
          >
            <Form.Item
              name="title"
              label="Title"
              rules={[
                { required: true, message: 'Please enter a title' },
                { max: 100, message: 'Maximum 100 characters' }
              ]}
            >
              <Input
                placeholder="e.g., New Features Available, System Maintenance"
                prefix={<BellOutlined style={{ color: '#1890ff' }} />}
              />
            </Form.Item>

            <Form.Item
              name="message"
              label="Message"
              rules={[
                { required: true, message: 'Please enter a message' },
                { max: 500, message: 'Maximum 500 characters' }
              ]}
            >
              <TextArea
                rows={6}
                placeholder="Write your announcement message here...&#10;&#10;Be clear and concise. Users will see this in their notification panel."
                showCount
                maxLength={500}
                style={{ fontSize: '15px' }}
              />
            </Form.Item>

            <Form.Item
              name="targetRole"
              label="Target Audience"
              rules={[{ required: true, message: 'Please select an audience' }]}
              initialValue="all"
            >
              <Select
                size="large"
                placeholder="Select who will receive this announcement"
              >
                <Option value="all">
                  <Space>
                    <GlobalOutlined style={{ color: '#1890ff' }} />
                    <span><strong>All Users</strong> - Everyone on the platform</span>
                  </Space>
                </Option>
                <Option value="buyer">
                  <Space>
                    <UserOutlined style={{ color: '#52c41a' }} />
                    <span><strong>Buyers</strong> - Customers only</span>
                  </Space>
                </Option>
                <Option value="seller">
                  <Space>
                    <ShopOutlined style={{ color: '#faad14' }} />
                    <span><strong>Sellers</strong> - Vendors only</span>
                  </Space>
                </Option>
                <Option value="cooperative">
                  <Space>
                    <TeamOutlined style={{ color: '#722ed1' }} />
                    <span><strong>Cooperatives</strong> - Cooperative members only</span>
                  </Space>
                </Option>
              </Select>
            </Form.Item>

            <Form.Item style={{ marginBottom: 0 }}>
              <Space style={{ width: '100%', justifyContent: 'center' }} size="middle">
                <Button
                  type="primary"
                  htmlType="submit"
                  loading={loading}
                  icon={<SendOutlined />}
                  size="large"
                  style={{
                    minWidth: '180px',
                    height: '48px',
                    fontSize: '16px',
                    fontWeight: '600',
                    borderRadius: '8px'
                  }}
                >
                  {loading ? 'Sending...' : 'Send Now'}
                </Button>
                <Button
                  onClick={() => form.resetFields()}
                  size="large"
                  disabled={loading}
                  style={{
                    height: '48px',
                    borderRadius: '8px'
                  }}
                >
                  Clear
                </Button>
              </Space>
            </Form.Item>
          </Form>
        </Space>
      </Card>
    </div>
  );
};

export default AnnouncementManagement;
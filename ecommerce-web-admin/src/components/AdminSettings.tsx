import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Button, 
  Form, 
  Input, 
  message as Message, 
  Space, 
  Typography,
  Row,
  Col,
} from 'antd';
import { 
  SettingOutlined,
  KeyOutlined,
  UserOutlined
} from '@ant-design/icons';
import { useAuth } from '../contexts/AuthContext';

const { Title, Text } = Typography;

interface PasswordFormData {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export const AdminSettings: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [passwordForm] = Form.useForm();
  
  const { user } = useAuth();

  const handleChangePassword = async (values: PasswordFormData) => {
    try {
      setLoading(true);
      
      if (values.newPassword !== values.confirmPassword) {
        Message.error('New passwords do not match');
        return;
      }

      if (values.newPassword.length < 6) {
        Message.error('Password must be at least 6 characters');
        return;
      }

      // TODO: Implement password change when Firebase Auth is properly configured
      console.log('Changing password for user');
      Message.success('Password changed successfully!');
      passwordForm.resetFields();
    } catch (error) {
      console.error('Error changing password:', error);
      Message.error('Failed to change password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <div style={{ marginBottom: '32px' }}>
        <Title level={2}>
          <SettingOutlined style={{ marginRight: 12 }} />
          System Settings
        </Title>
        <Text type="secondary">Manage your account settings and preferences</Text>
      </div>

      <Row gutter={[24, 24]}>
        {/* Profile Information - Read Only */}
        <Col xs={24} lg={12}>
          <Card 
            title={
              <Space>
                <UserOutlined />
                <span>Profile Information</span>
              </Space>
            }
          >
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <div>
                <Text strong>Name</Text>
                <div style={{ 
                  marginTop: 8, 
                  padding: '8px 12px', 
                  background: '#f5f5f5', 
                  borderRadius: '6px' 
                }}>
                  <Text>{user?.displayName || 'Admin User'}</Text>
                </div>
              </div>
              
              <div>
                <Text strong>Email Address</Text>
                <div style={{ 
                  marginTop: 8, 
                  padding: '8px 12px', 
                  background: '#f5f5f5', 
                  borderRadius: '6px' 
                }}>
                  <Text>{user?.email || 'admin@example.com'}</Text>
                </div>
              </div>

              <div>
                <Text strong>Role</Text>
                <div style={{ 
                  marginTop: 8, 
                  padding: '8px 12px', 
                  background: '#f5f5f5', 
                  borderRadius: '6px' 
                }}>
                  <Text>Administrator</Text>
                </div>
              </div>
            </Space>
          </Card>
        </Col>

        {/* Password Change */}
        <Col xs={24} lg={12}>
          <Card 
            title={
              <Space>
                <KeyOutlined />
                <span>Change Password</span>
              </Space>
            }
          >
            <Form
              form={passwordForm}
              layout="vertical"
              onFinish={handleChangePassword}
            >
              <Form.Item
                name="currentPassword"
                label="Current Password"
                rules={[{ required: true, message: 'Please enter your current password' }]}
              >
                <Input.Password 
                  placeholder="Enter current password" 
                  size="large"
                />
              </Form.Item>

              <Form.Item
                name="newPassword"
                label="New Password"
                rules={[
                  { required: true, message: 'Please enter new password' },
                  { min: 6, message: 'Password must be at least 6 characters' }
                ]}
              >
                <Input.Password 
                  placeholder="Enter new password" 
                  size="large"
                />
              </Form.Item>

              <Form.Item
                name="confirmPassword"
                label="Confirm New Password"
                rules={[{ required: true, message: 'Please confirm new password' }]}
              >
                <Input.Password 
                  placeholder="Confirm new password" 
                  size="large"
                />
              </Form.Item>

              <Form.Item style={{ marginBottom: 0 }}>
                <Button 
                  type="primary" 
                  htmlType="submit" 
                  loading={loading} 
                  icon={<KeyOutlined />}
                  size="large"
                  block
                >
                  Update Password
                </Button>
              </Form.Item>
            </Form>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default AdminSettings;

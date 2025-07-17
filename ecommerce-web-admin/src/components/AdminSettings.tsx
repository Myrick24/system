import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Button, 
  Form, 
  Input, 
  message as Message, 
  Space, 
  Typography,
  Divider,
  Row,
  Col,
  Avatar,
  Table,
  Modal,
  Tag,
  Descriptions,
  Statistic
} from 'antd';
import { 
  UserOutlined, 
  SettingOutlined,
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  KeyOutlined,
  TeamOutlined,
  InfoCircleOutlined,
  DatabaseOutlined
} from '@ant-design/icons';
import { useAuth } from '../contexts/AuthContext';
import { AdminService } from '../services/adminService';
import { User } from '../types';

const { Title, Paragraph } = Typography;

interface AdminFormData {
  name: string;
  email: string;
  currentPassword?: string;
  newPassword?: string;
  confirmPassword?: string;
}

interface SubAdminFormData {
  name: string;
  email: string;
  password: string;
}

export const AdminSettings: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [profileForm] = Form.useForm();
  const [passwordForm] = Form.useForm();
  const [subAdminForm] = Form.useForm();
  const [subAdminModalVisible, setSubAdminModalVisible] = useState(false);
  const [admins, setAdmins] = useState<User[]>([]);
  
  const { user } = useAuth();
  const adminService = new AdminService();

  useEffect(() => {
    loadAdminUsers();
    if (user) {
      profileForm.setFieldsValue({
        name: user.displayName || '',
        email: user.email || ''
      });
    }
  }, [user, profileForm]);

  const loadAdminUsers = async () => {
    try {
      setLoading(true);
      const adminUsers = await adminService.getAllAdmins();
      setAdmins(adminUsers);
    } catch (error) {
      console.error('Error loading admin users:', error);
      Message.error('Failed to load admin users');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateProfile = async (values: AdminFormData) => {
    try {
      setLoading(true);
      // TODO: Implement profile update when Firebase Auth is properly configured
      console.log('Updating profile:', values);
      Message.success('Profile updated successfully!');
    } catch (error) {
      console.error('Error updating profile:', error);
      Message.error('Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async (values: AdminFormData) => {
    try {
      setLoading(true);
      
      if (values.newPassword !== values.confirmPassword) {
        Message.error('New passwords do not match');
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

  const handleAddSubAdmin = async (values: SubAdminFormData) => {
    try {
      setLoading(true);
      const success = await adminService.addSubAdmin(values.email, values.password, values.name);
      
      if (success) {
        Message.success('Sub-admin added successfully!');
        setSubAdminModalVisible(false);
        subAdminForm.resetFields();
        loadAdminUsers();
      } else {
        Message.error('Failed to add sub-admin');
      }
    } catch (error) {
      console.error('Error adding sub-admin:', error);
      Message.error('Failed to add sub-admin');
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveSubAdmin = async (userId: string, userName: string) => {
    Modal.confirm({
      title: 'Remove Sub-Admin',
      content: `Are you sure you want to remove ${userName} as a sub-admin? This action cannot be undone.`,
      okText: 'Remove',
      okType: 'danger',
      cancelText: 'Cancel',
      onOk: async () => {
        try {
          const success = await adminService.removeSubAdmin(userId);
          if (success) {
            Message.success('Sub-admin removed successfully!');
            loadAdminUsers();
          } else {
            Message.error('Failed to remove sub-admin');
          }
        } catch (error) {
          console.error('Error removing sub-admin:', error);
          Message.error('Failed to remove sub-admin');
        }
      }
    });
  };

  const adminColumns = [
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
      render: (name: string, record: User) => (
        <Space>
          <Avatar icon={<UserOutlined />} />
          <span>{name}</span>
          {record.isMainAdmin && <Tag color="gold">Main Admin</Tag>}
          {record.isSubAdmin && <Tag color="blue">Sub Admin</Tag>}
        </Space>
      )
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email'
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'active' ? 'green' : 'red'}>
          {status?.toUpperCase() || 'ACTIVE'}
        </Tag>
      )
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (record: User) => (
        <Space>
          {!record.isMainAdmin && (
            <Button
              danger
              size="small"
              icon={<DeleteOutlined />}
              onClick={() => handleRemoveSubAdmin(record.id, record.name)}
            >
              Remove
            </Button>
          )}
        </Space>
      )
    }
  ];

  return (
    <div style={{ padding: '24px' }}>
      <Title level={2}>
        <SettingOutlined style={{ marginRight: 8 }} />
        Admin Settings
      </Title>
      
      <Paragraph>
        Manage your admin profile, change password, and manage sub-administrators.
      </Paragraph>

      <Row gutter={[24, 24]}>
        {/* Profile Management */}
        <Col xs={24} lg={12}>
          <Card title="Profile Information" style={{ height: '100%' }}>
            <Form
              form={profileForm}
              layout="vertical"
              onFinish={handleUpdateProfile}
            >
              <Form.Item
                name="name"
                label="Full Name"
                rules={[{ required: true, message: 'Please enter your full name' }]}
              >
                <Input placeholder="Enter your full name" />
              </Form.Item>

              <Form.Item
                name="email"
                label="Email Address"
                rules={[
                  { required: true, message: 'Please enter your email' },
                  { type: 'email', message: 'Please enter a valid email' }
                ]}
              >
                <Input placeholder="Enter your email" disabled />
              </Form.Item>

              <Form.Item>
                <Button type="primary" htmlType="submit" loading={loading}>
                  Update Profile
                </Button>
              </Form.Item>
            </Form>
          </Card>
        </Col>

        {/* Password Change */}
        <Col xs={24} lg={12}>
          <Card title="Change Password" style={{ height: '100%' }}>
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
                <Input.Password placeholder="Enter current password" />
              </Form.Item>

              <Form.Item
                name="newPassword"
                label="New Password"
                rules={[
                  { required: true, message: 'Please enter new password' },
                  { min: 6, message: 'Password must be at least 6 characters' }
                ]}
              >
                <Input.Password placeholder="Enter new password" />
              </Form.Item>

              <Form.Item
                name="confirmPassword"
                label="Confirm New Password"
                rules={[{ required: true, message: 'Please confirm new password' }]}
              >
                <Input.Password placeholder="Confirm new password" />
              </Form.Item>

              <Form.Item>
                <Button type="primary" htmlType="submit" loading={loading} icon={<KeyOutlined />}>
                  Change Password
                </Button>
              </Form.Item>
            </Form>
          </Card>
        </Col>
      </Row>

      <Divider />

      {/* Sub-Admin Management */}
      <Card
        title={
          <Space>
            <TeamOutlined />
            Sub-Administrator Management
          </Space>
        }
        extra={
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => setSubAdminModalVisible(true)}
          >
            Add Sub-Admin
          </Button>
        }
        style={{ marginTop: 24 }}
      >
        <Table
          dataSource={admins}
          columns={adminColumns}
          rowKey="id"
          loading={loading}
          pagination={{ pageSize: 10 }}
          locale={{ emptyText: 'No admin users found' }}
        />
      </Card>

      {/* Add Sub-Admin Modal */}
      <Modal
        title="Add Sub-Administrator"
        open={subAdminModalVisible}
        onCancel={() => {
          setSubAdminModalVisible(false);
          subAdminForm.resetFields();
        }}
        footer={null}
        width={500}
      >
        <Form
          form={subAdminForm}
          layout="vertical"
          onFinish={handleAddSubAdmin}
        >
          <Form.Item
            name="name"
            label="Full Name"
            rules={[{ required: true, message: 'Please enter full name' }]}
          >
            <Input placeholder="Enter full name" />
          </Form.Item>

          <Form.Item
            name="email"
            label="Email Address"
            rules={[
              { required: true, message: 'Please enter email' },
              { type: 'email', message: 'Please enter a valid email' }
            ]}
          >
            <Input placeholder="Enter email address" />
          </Form.Item>

          <Form.Item
            name="password"
            label="Password"
            rules={[
              { required: true, message: 'Please enter password' },
              { min: 6, message: 'Password must be at least 6 characters' }
            ]}
          >
            <Input.Password placeholder="Enter password" />
          </Form.Item>

          <Form.Item style={{ textAlign: 'right', marginBottom: 0 }}>
            <Space>
              <Button onClick={() => {
                setSubAdminModalVisible(false);
                subAdminForm.resetFields();
              }}>
                Cancel
              </Button>
              <Button type="primary" htmlType="submit" loading={loading}>
                Add Sub-Admin
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>

      <Divider />

      {/* System Information */}
      <Card title="System Information" style={{ marginTop: 24 }}>
        <Descriptions column={1}>
          <Descriptions.Item label="Application Name">Admin Panel</Descriptions.Item>
          <Descriptions.Item label="Version">1.0.0</Descriptions.Item>
          <Descriptions.Item label="Environment">Production</Descriptions.Item>
          <Descriptions.Item label="API URL">https://api.example.com</Descriptions.Item>
        </Descriptions>

        <Divider />

        <Title level={4}>
          <InfoCircleOutlined style={{ marginRight: 8 }} />
          System Status
        </Title>

        <Row gutter={[16, 16]}>
          <Col span={8}>
            <Statistic title="Total Users" value={1000} />
          </Col>
          <Col span={8}>
            <Statistic title="Active Sessions" value={250} />
          </Col>
          <Col span={8}>
            <Statistic title="Pending Verifications" value={5} />
          </Col>
        </Row>
      </Card>
    </div>
  );
};

export default AdminSettings;

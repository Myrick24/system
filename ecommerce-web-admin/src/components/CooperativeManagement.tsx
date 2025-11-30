import React, { useState, useEffect } from 'react';
import {
  Card,
  Form,
  Input,
  Button,
  message,
  Space,
  Typography,
  Table,
  Tag,
  Modal,
  Divider,
  Alert,
  Tooltip
} from 'antd';
import {
  UserAddOutlined,
  TeamOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  ReloadOutlined,
  DeleteOutlined,
  InfoCircleOutlined,
  PlusOutlined,
  EditOutlined
} from '@ant-design/icons';
import { collection, query, where, getDocs, doc, updateDoc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '../services/firebase';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { useAuth } from '../contexts/AuthContext';

const { Title, Text, Paragraph } = Typography;
const { confirm } = Modal;

interface CooperativeUser {
  id: string;
  name: string;
  email: string;
  role: string;
  status: string;
  createdAt?: any;
  phone?: string;
  location?: string;
}

interface CreateCoopFormValues {
  name: string;
  email: string;
  password: string;
  phone?: string;
  location?: string;
}

export const CooperativeManagement: React.FC = () => {
  const [form] = Form.useForm();
  const [editForm] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [cooperativeUsers, setCooperativeUsers] = useState<CooperativeUser[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [editingCoop, setEditingCoop] = useState<CooperativeUser | null>(null);
  const [editLoading, setEditLoading] = useState(false);
  const { user } = useAuth();

  useEffect(() => {
    loadCooperativeUsers();
  }, []);

  const loadCooperativeUsers = async () => {
    setLoadingUsers(true);
    try {
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where('role', '==', 'cooperative'));
      const querySnapshot = await getDocs(q);
      
      const users: CooperativeUser[] = [];
      querySnapshot.forEach((doc) => {
        users.push({
          id: doc.id,
          ...doc.data()
        } as CooperativeUser);
      });

      setCooperativeUsers(users);
    } catch (error) {
      console.error('Error loading cooperative users:', error);
      message.error('Failed to load cooperative users');
    } finally {
      setLoadingUsers(false);
    }
  };

  const createNewCooperativeAccount = async (values: CreateCoopFormValues) => {
    setLoading(true);
    try {
      const { name, email, password, phone, location } = values;
      const emailLower = email.toLowerCase().trim();

      // Check if user already exists in Firestore
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where('email', '==', emailLower));
      const querySnapshot = await getDocs(q);

      if (!querySnapshot.empty) {
        message.error('A user with this email already exists!');
        setLoading(false);
        return;
      }

      // Get current admin info before account creation
      const adminAuthToken = await auth.currentUser?.getIdToken();
      const adminEmail = auth.currentUser?.email;
      const adminUID = auth.currentUser?.uid;

      // Create Firebase Authentication account for cooperative
      const userCredential = await createUserWithEmailAndPassword(auth, emailLower, password);
      const userId = userCredential.user.uid;

      // Create Firestore document
      const userRef = doc(db, 'users', userId);
      await setDoc(userRef, {
        name: name.trim(),
        email: emailLower,
        phone: phone?.trim() || '',
        location: location?.trim() || '',
        role: 'cooperative',
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      });

      message.success(`Successfully created cooperative account for ${name}!`);
      form.resetFields();
      loadCooperativeUsers();

      // Instead of signing out, just refresh the cooperative users and stay on the page
      // The admin session remains active
      // Optionally, you can show a message that the account was created
      // Already handled above with message.success
      // No redirect or sign out

    } catch (error: any) {
      console.error('Error creating cooperative account:', error);
      if (error.code === 'auth/email-already-in-use') {
        message.error('This email is already registered in Firebase Authentication.');
      } else if (error.code === 'auth/weak-password') {
        message.error('Password should be at least 6 characters.');
      } else if (error.code === 'auth/invalid-email') {
        message.error('Invalid email address format.');
      } else {
        message.error(`Failed to create account: ${error.message}`);
      }
    } finally {
      setLoading(false);
    }
  };

  const removeCooperativeRole = (userId: string, userName: string) => {
    confirm({
      title: 'Remove Cooperative Role',
      icon: <CloseCircleOutlined />,
      content: `Are you sure you want to remove cooperative role from ${userName}? They will be changed back to a buyer.`,
      okText: 'Yes, Remove',
      okType: 'danger',
      cancelText: 'Cancel',
      async onOk() {
        try {
          const userRef = doc(db, 'users', userId);
          await updateDoc(userRef, {
            role: 'buyer',
            updatedAt: new Date()
          });

          message.success(`Removed cooperative role from ${userName}`);
          loadCooperativeUsers();
        } catch (error) {
          console.error('Error removing cooperative role:', error);
          message.error('Failed to remove cooperative role');
        }
      }
    });
  };

  const deleteCooperativeAccount = (userId: string, userName: string) => {
    confirm({
      title: 'Delete Cooperative Account',
      icon: <DeleteOutlined style={{ color: '#ff4d4f' }} />,
      content: (
        <div>
          <Alert
            message="This action cannot be undone!"
            type="error"
            showIcon
            style={{ marginBottom: '12px' }}
          />
          <p>This will permanently delete the cooperative account for <strong>{userName}</strong>.</p>
          <p style={{ color: '#ff4d4f', fontWeight: 600 }}>All associated data will be marked as deleted.</p>
        </div>
      ),
      okText: 'Yes, Delete Permanently',
      okType: 'danger',
      cancelText: 'Cancel',
      async onOk() {
        try {
          const userRef = doc(db, 'users', userId);
          
          // Soft delete by marking as deleted
          await updateDoc(userRef, {
            status: 'deleted',
            deletedAt: new Date(),
            deletedBy: auth.currentUser?.uid,
            originalRole: 'cooperative',
            updatedAt: new Date()
          });

          message.success(`Successfully deleted cooperative account: ${userName}`);
          loadCooperativeUsers();
        } catch (error) {
          console.error('Error deleting cooperative account:', error);
          message.error('Failed to delete cooperative account');
        }
      }
    });
  };

  const openEditModal = (coop: CooperativeUser) => {
    setEditingCoop(coop);
    editForm.setFieldsValue({
      name: coop.name,
      phone: coop.phone || '',
      location: coop.location || ''
    });
    setEditModalVisible(true);
  };

  const closeEditModal = () => {
    setEditModalVisible(false);
    setEditingCoop(null);
    editForm.resetFields();
  };

  const handleEditCooperative = async (values: any) => {
    if (!editingCoop) return;

    setEditLoading(true);
    try {
      const userRef = doc(db, 'users', editingCoop.id);
      await updateDoc(userRef, {
        name: values.name.trim(),
        phone: values.phone?.trim() || '',
        location: values.location?.trim() || '',
        updatedAt: new Date()
      });

      message.success(`Successfully updated ${values.name}!`);
      closeEditModal();
      loadCooperativeUsers();
    } catch (error: any) {
      console.error('Error updating cooperative:', error);
      message.error(`Failed to update: ${error.message}`);
    } finally {
      setEditLoading(false);
    }
  };

  const columns = [
    {
      title: 'Cooperative Name',
      dataIndex: 'name',
      key: 'name',
      render: (name: string, record: CooperativeUser) => (
        <Space>
          <TeamOutlined style={{ fontSize: '18px', color: '#52c41a' }} />
          <span><strong>{name || 'N/A'}</strong></span>
        </Space>
      )
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email'
    },
    {
      title: 'Phone',
      dataIndex: 'phone',
      key: 'phone',
      render: (phone: string) => phone || 'N/A'
    },
    {
      title: 'Pickup Location',
      dataIndex: 'location',
      key: 'location',
      render: (location: string) => location || 'Not set'
    },
    {
      title: 'Role',
      dataIndex: 'role',
      key: 'role',
      render: (role: string) => (
        <Tag color="green">{role?.toUpperCase()}</Tag>
      )
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'active' ? 'success' : 'default'}>
          {status?.toUpperCase() || 'ACTIVE'}
        </Tag>
      )
    },
    {
      title: 'User ID',
      dataIndex: 'id',
      key: 'id',
      render: (id: string) => (
        <Tooltip title={id}>
          <Text copyable={{ text: id }} style={{ fontSize: '12px', color: '#999' }}>
            {id.substring(0, 8)}...
          </Text>
        </Tooltip>
      )
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: CooperativeUser) => (
        <Space wrap>
          <Button
            type="primary"
            ghost
            icon={<EditOutlined />}
            onClick={() => openEditModal(record)}
            size="small"
          >
            Edit
          </Button>
          <Button
            type="primary"
            danger
            icon={<DeleteOutlined />}
            onClick={() => deleteCooperativeAccount(record.id, record.name)}
            size="small"
          >
            Delete
          </Button>
        </Space>
      )
    }
  ];

  return (
    <div style={{ padding: '24px' }}>
      <Title level={2}>
        <TeamOutlined /> Cooperative Management
      </Title>
      <Paragraph>
        Create and manage cooperative accounts. Cooperative members have access to the Cooperative Dashboard
        where they can manage deliveries, pickups, and payment collection for the cooperative.
      </Paragraph>

      <Card
        title={
          <Space>
            <UserAddOutlined />
            <span>Create New Cooperative Account</span>
          </Space>
        }
        style={{ marginBottom: '24px' }}
      >
        <Alert
          message="Create New Cooperative Account"
          description="Admin can directly create a new cooperative account. Enter the cooperative name (not individual person's name). The account can be used by multiple members of the cooperative."
          type="info"
          icon={<InfoCircleOutlined />}
          showIcon
          style={{ marginBottom: '24px' }}
        />

        <Form
          form={form}
          layout="vertical"
          onFinish={createNewCooperativeAccount}
        >
          <Form.Item
            label="Cooperative Name"
            name="name"
            rules={[
              { required: true, message: 'Please enter the cooperative name' },
              { min: 2, message: 'Name must be at least 2 characters' }
            ]}
            extra="Enter the name of the cooperative organization"
          >
            <Input
              placeholder="Enter cooperative name (e.g., Coop Kapatiran, Samahan Coop)"
              size="large"
            />
          </Form.Item>

          <Form.Item
            label="Email Address"
            name="email"
            rules={[
              { required: true, message: 'Please enter the email' },
              { type: 'email', message: 'Please enter a valid email address' }
            ]}
            extra="This will be the login email for the cooperative account"
          >
            <Input
              placeholder="Enter email (e.g., coopkapatiran@example.com)"
              size="large"
              type="email"
            />
          </Form.Item>

          <Form.Item
            label="Password"
            name="password"
            rules={[
              { required: true, message: 'Please enter a password' },
              { min: 6, message: 'Password must be at least 6 characters' }
            ]}
            extra="Minimum 6 characters. Share this password with the cooperative members who will manage this account."
          >
            <Input.Password
              placeholder="Enter password (min 6 characters)"
              size="large"
            />
          </Form.Item>

          <Form.Item
            label="Contact Phone Number (Optional)"
            name="phone"
            extra="Contact number for the cooperative office"
          >
            <Input
              placeholder="Enter contact number (e.g., +639123456789)"
              size="large"
            />
          </Form.Item>

          <Form.Item
            label="Pickup Location"
            name="location"
            rules={[
              { required: true, message: 'Please enter the pickup location' },
              { min: 5, message: 'Location must be at least 5 characters' }
            ]}
            extra="Enter the full address where buyers can pick up their orders"
          >
            <Input.TextArea
              placeholder="Enter complete pickup address (e.g., 123 Main St, Barangay Centro, City, Province)"
              size="large"
              rows={3}
            />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button
                type="primary"
                htmlType="submit"
                icon={<PlusOutlined />}
                loading={loading}
                size="large"
              >
                Create Cooperative Account
              </Button>
              <Button
                onClick={() => form.resetFields()}
                disabled={loading}
              >
                Clear
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Card>

      <Card
        title={
          <Space>
            <TeamOutlined />
            <span>Current Cooperatives ({cooperativeUsers.length})</span>
            <Button
              type="text"
              icon={<ReloadOutlined />}
              onClick={loadCooperativeUsers}
              loading={loadingUsers}
            >
              Refresh
            </Button>
          </Space>
        }
      >
        {cooperativeUsers.length === 0 && !loadingUsers ? (
          <Alert
            message="No Cooperatives Yet"
            description="Assign cooperative roles to users to enable them to manage deliveries and payments for the cooperative."
            type="warning"
            showIcon
          />
        ) : (
          <Table
            dataSource={cooperativeUsers}
            columns={columns}
            rowKey="id"
            loading={loadingUsers}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>

      <Card
        title="Cooperative Dashboard Features"
        style={{ marginTop: '24px' }}
      >
        <Paragraph>
          <strong>Cooperative members have access to:</strong>
        </Paragraph>
        <ul>
          <li>📦 View all "Cooperative Delivery" orders</li>
          <li>📍 Manage "Pickup at Coop" orders</li>
          <li>✅ Update delivery statuses (pending → processing → delivered)</li>
          <li>💰 Track and collect payments (COD and GCash)</li>
          <li>📊 View delivery statistics and analytics</li>
          <li>🔔 Real-time order notifications</li>
        </ul>
        <Divider />
        <Paragraph type="secondary">
          <strong>Note:</strong> Cooperative members can only access the Cooperative Dashboard. They cannot access admin features,
          browse products, or place orders. This role is specifically for managing cooperative deliveries and payments.
        </Paragraph>
      </Card>

      {/* Edit Cooperative Modal */}
      <Modal
        title={
          <Space>
            <EditOutlined />
            <span>Edit Cooperative Information</span>
          </Space>
        }
        open={editModalVisible}
        onCancel={closeEditModal}
        footer={null}
        width={600}
      >
        <Form
          form={editForm}
          layout="vertical"
          onFinish={handleEditCooperative}
        >
          <Alert
            message="Update Cooperative Information"
            description="You can update the cooperative name, contact phone, and pickup location. Email cannot be changed."
            type="info"
            icon={<InfoCircleOutlined />}
            showIcon
            style={{ marginBottom: '24px' }}
          />

          <Form.Item
            label="Cooperative Name"
            name="name"
            rules={[
              { required: true, message: 'Please enter the cooperative name' },
              { min: 2, message: 'Name must be at least 2 characters' }
            ]}
          >
            <Input
              placeholder="Enter cooperative name"
              size="large"
            />
          </Form.Item>

          <Form.Item
            label="Contact Phone Number"
            name="phone"
          >
            <Input
              placeholder="Enter contact number (e.g., +639123456789)"
              size="large"
            />
          </Form.Item>

          <Form.Item
            label="Pickup Location"
            name="location"
            rules={[
              { required: true, message: 'Please enter the pickup location' },
              { min: 5, message: 'Location must be at least 5 characters' }
            ]}
          >
            <Input.TextArea
              placeholder="Enter complete pickup address"
              size="large"
              rows={3}
            />
          </Form.Item>

          <Form.Item>
            <Space>
              <Button
                type="primary"
                htmlType="submit"
                icon={<EditOutlined />}
                loading={editLoading}
                size="large"
              >
                Update Cooperative
              </Button>
              <Button
                onClick={closeEditModal}
                disabled={editLoading}
              >
                Cancel
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

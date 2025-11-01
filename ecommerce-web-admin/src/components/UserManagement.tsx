import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Tag, Space, Tabs, message, Modal, Spin, Tooltip } from 'antd';
import { 
  CheckOutlined, 
  CloseOutlined, 
  EyeOutlined,
  ReloadOutlined,
  DeleteOutlined,
  HistoryOutlined,
  UndoOutlined,
  ExclamationCircleOutlined
} from '@ant-design/icons';
import { UserService } from '../services/userService';
import { User } from '../types';
import DeleteUserModal from './DeleteUserModal';
import AuditLogsModal from './AuditLogsModal';
import { useAuth } from '../contexts/AuthContext';

const { TabPane } = Tabs;

export const UserManagement: React.FC = () => {
  const { user } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [buyers, setBuyers] = useState<User[]>([]);
  const [sellers, setSellers] = useState<User[]>([]);
  const [pendingSellers, setPendingSellers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('pending-sellers');
  const [deleteModalVisible, setDeleteModalVisible] = useState(false);
  const [auditModalVisible, setAuditModalVisible] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);
  const userService = new UserService();

  useEffect(() => {
    loadUserData();
  }, []);

  const loadUserData = async () => {
    try {
      setLoading(true);
      const [allUsers, allBuyers, allSellers, pendingSellersData] = await Promise.all([
        userService.getAllUsers(),
        userService.getUsersByRole('buyer'),
        userService.getUsersByRole('seller'),
        userService.getPendingSellers()
      ]);

      setUsers(allUsers);
      setBuyers(allBuyers);
      setSellers(allSellers.filter(seller => seller.status === 'approved'));
      setPendingSellers(pendingSellersData);
    } catch (error) {
      console.error('Error loading user data:', error);
      message.error('Failed to load user data');
    } finally {
      setLoading(false);
    }
  };

  const handleApproveSeller = async (userId: string, userName: string) => {
    try {
      const success = await userService.approveSeller(userId);
      if (success) {
        message.success(`${userName} approved as seller`);
        loadUserData(); // Reload data
      } else {
        message.error('Failed to approve seller');
      }
    } catch (error) {
      console.error('Error approving seller:', error);
      message.error('Failed to approve seller');
    }
  };

  const handleRejectSeller = async (userId: string, userName: string) => {
    Modal.confirm({
      title: 'Reject Seller Application',
      content: `Are you sure you want to reject ${userName}'s seller application?`,
      onOk: async () => {
        try {
          const success = await userService.rejectSeller(userId);
          if (success) {
            message.success(`${userName}'s application rejected`);
            loadUserData(); // Reload data
          } else {
            message.error('Failed to reject seller');
          }
        } catch (error) {
          console.error('Error rejecting seller:', error);
          message.error('Failed to reject seller');
        }
      }
    });
  };

  const getStatusColor = (status?: string) => {
    if (!status) return 'default';
    
    switch (status) {
      case 'active': return 'green';
      case 'approved': return 'green';
      case 'pending': return 'orange';
      case 'suspended': return 'red';
      case 'rejected': return 'red';
      case 'deleted': return 'volcano';
      default: return 'default';
    }
  };

  const baseColumns = [
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
      sorter: (a: User, b: User) => a.name.localeCompare(b.name)
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email'
    },
    {
      title: 'Role',
      dataIndex: 'role',
      key: 'role',
      render: (role?: string) => (
        <Tag color={role === 'admin' ? 'purple' : role === 'seller' ? 'blue' : 'green'}>
          {role ? role.toUpperCase() : 'N/A'}
        </Tag>
      )
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status?: string) => (
        <Tag color={getStatusColor(status)}>
          {status ? status.toUpperCase() : 'N/A'}
        </Tag>
      )
    }
  ];

  const pendingSellerColumns = [
    ...baseColumns,
    {
      title: 'Actions',
      key: 'actions',
      render: (record: User) => (
        <Space>
          <Button
            type="primary"
            icon={<CheckOutlined />}
            size="small"
            onClick={() => handleApproveSeller(record.id, record.name)}
          >
            Approve
          </Button>
          <Button
            danger
            icon={<CloseOutlined />}
            size="small"
            onClick={() => handleRejectSeller(record.id, record.name)}
          >
            Reject
          </Button>
        </Space>
      )
    }
  ];

  const userColumns = [
    ...baseColumns,
    {
      title: 'Actions',
      key: 'actions',
      render: (record: User) => (
        <Space>
          {record.status === 'deleted' ? (
            <Tooltip title="Restore deleted user">
              <Button
                type="primary"
                icon={<UndoOutlined />}
                size="small"
                onClick={() => handleRestoreUser(record)}
              >
                Restore
              </Button>
            </Tooltip>
          ) : (
            <Tooltip title="Delete user account">
              <Button
                danger
                icon={<DeleteOutlined />}
                size="small"
                onClick={() => handleDeleteUser(record)}
              >
                Delete
              </Button>
            </Tooltip>
          )}
        </Space>
      )
    }
  ];

  const handleDeleteUser = (user: User) => {
    console.log('handleDeleteUser called with user:', user);
    setSelectedUser(user);
    setDeleteModalVisible(true);
    console.log('Modal should now be visible');
  };

  const handleRestoreUser = async (userToRestore: User) => {
    Modal.confirm({
      title: 'Restore User Account',
      icon: <UndoOutlined />,
      content: `Are you sure you want to restore ${userToRestore.name}'s account?`,
      okText: 'Restore',
      cancelText: 'Cancel',
      onOk: async () => {
        try {
          if (!user) {
            message.error('Admin user not authenticated');
            return;
          }
          const adminId = user.uid || 'unknown-admin';
          const result = await userService.restoreUser(userToRestore.id, adminId);
          if (result.success) {
            message.success(result.message);
            loadUserData(); // Reload data
          } else {
            message.error(result.message);
          }
        } catch (error) {
          console.error('Error restoring user:', error);
          message.error('Failed to restore user');
        }
      }
    });
  };

  const confirmDeleteUser = async (userId: string, deleteType: 'soft' | 'hard', reason: string) => {
    console.log('=== DELETE USER INITIATED ===');
    console.log('User ID:', userId);
    console.log('Delete Type:', deleteType);
    console.log('Reason:', reason);
    console.log('Current Auth User:', user);
    
    try {
      setDeleteLoading(true);
      
      if (!user) {
        console.error('ERROR: Admin user not authenticated');
        message.error('Admin user not authenticated');
        return;
      }
      
      const adminId = user.uid || 'unknown-admin';
      console.log('Admin ID:', adminId);
      console.log('Calling userService.deleteUser...');
      
      const result = await userService.deleteUser(userId, adminId, reason, deleteType);
      
      console.log('Delete result:', result);
      
      if (result.success) {
        console.log('SUCCESS: User deleted successfully');
        message.success(result.message);
        setDeleteModalVisible(false);
        setSelectedUser(null);
        console.log('Reloading user data...');
        await loadUserData(); // Reload data
        console.log('User data reloaded');
      } else {
        console.error('FAILED: User deletion failed:', result.message);
        message.error(result.message);
      }
    } catch (error) {
      console.error('=== DELETE USER ERROR ===');
      console.error('Error object:', error);
      console.error('Error type:', typeof error);
      console.error('Error message:', error instanceof Error ? error.message : 'Unknown error');
      console.error('Error stack:', error instanceof Error ? error.stack : 'No stack trace');
      
      const errorMessage = error instanceof Error ? error.message : 'Failed to delete user';
      message.error(`Error: ${errorMessage}`);
    } finally {
      setDeleteLoading(false);
      console.log('=== DELETE USER COMPLETED ===');
    }
  };

  return (
    <div style={{ padding: '24px' }}>
      <Card
        title="User Management"
        extra={
          <Space>
            <Button
              icon={<HistoryOutlined />}
              onClick={() => setAuditModalVisible(true)}
            >
              View Audit Logs
            </Button>
            <Button
              icon={<ReloadOutlined />}
              onClick={loadUserData}
              loading={loading}
            >
              Refresh
            </Button>
          </Space>
        }
      >
        <Tabs activeKey={activeTab} onChange={setActiveTab}>
          <TabPane tab={`Pending Sellers (${pendingSellers.length})`} key="pending-sellers">
            <Table
              dataSource={pendingSellers}
              columns={pendingSellerColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`All Users (${users.length})`} key="all-users">
            <Table
              dataSource={users}
              columns={userColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`Buyers (${buyers.length})`} key="buyers">
            <Table
              dataSource={buyers}
              columns={userColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`Sellers (${sellers.length})`} key="sellers">
            <Table
              dataSource={sellers}
              columns={userColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>
        </Tabs>
      </Card>

      {selectedUser && (
        <DeleteUserModal
          visible={deleteModalVisible}
          user={selectedUser}
          onCancel={() => setDeleteModalVisible(false)}
          onConfirm={confirmDeleteUser}
          loading={deleteLoading}
        />
      )}

      {/* Audit Logs Modal */}
      <AuditLogsModal
        visible={auditModalVisible}
        onCancel={() => setAuditModalVisible(false)}
      />
    </div>
  );
};

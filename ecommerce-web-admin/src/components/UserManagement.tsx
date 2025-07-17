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

const { TabPane } = Tabs;

export const UserManagement: React.FC = () => {
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

  const handleUpdateUserStatus = async (userId: string, currentStatus?: string) => {
    const newStatus = currentStatus === 'active' ? 'suspended' : 'active';
    
    try {
      const success = await userService.updateUserStatus(userId, newStatus);
      if (success) {
        message.success(`User status updated to ${newStatus}`);
        loadUserData(); // Reload data
      } else {
        message.error('Failed to update user status');
      }
    } catch (error) {
      console.error('Error updating user status:', error);
      message.error('Failed to update user status');
    }
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
            <>
              <Button
                type={record.status === 'active' ? 'default' : 'primary'}
                size="small"
                onClick={() => handleUpdateUserStatus(record.id, record.status || 'suspended')}
              >
                {record.status === 'active' ? 'Suspend' : 'Activate'}
              </Button>
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
            </>
          )}
        </Space>
      )
    }
  ];

  const handleDeleteUser = (user: User) => {
    setSelectedUser(user);
    setDeleteModalVisible(true);
  };

  const handleRestoreUser = async (user: User) => {
    Modal.confirm({
      title: 'Restore User Account',
      icon: <UndoOutlined />,
      content: `Are you sure you want to restore ${user.name}'s account?`,
      okText: 'Restore',
      cancelText: 'Cancel',
      onOk: async () => {
        try {
          const result = await userService.restoreUser(user.id, 'current-admin-id'); // Replace with actual admin ID
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
    try {
      setDeleteLoading(true);
      const result = await userService.deleteUser(userId, 'current-admin-id', reason, deleteType); // Replace with actual admin ID
      
      if (result.success) {
        message.success(result.message);
        setDeleteModalVisible(false);
        setSelectedUser(null);
        loadUserData(); // Reload data
      } else {
        message.error(result.message);
      }
    } catch (error) {
      console.error('Error deleting user:', error);
      message.error('Failed to delete user');
    } finally {
      setDeleteLoading(false);
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

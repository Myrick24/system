import React, { useEffect, useState } from 'react';
import {
  Modal,
  Table,
  Tag,
  Typography,
  Space,
  Button,
  Card,
  Tooltip,
  Descriptions
} from 'antd';
import {
  HistoryOutlined,
  UserDeleteOutlined,
  UndoOutlined,
  InfoCircleOutlined
} from '@ant-design/icons';
import { UserService } from '../services/userService';

const { Text, Title } = Typography;

interface AuditLog {
  id: string;
  action: 'user_deletion' | 'user_restoration';
  targetUserId: string;
  targetUserData?: any;
  adminId: string;
  deleteType?: 'soft' | 'hard';
  reason?: string;
  timestamp: any;
  ip?: string;
  userAgent?: string;
}

interface AuditLogsModalProps {
  visible: boolean;
  onCancel: () => void;
}

export const AuditLogsModal: React.FC<AuditLogsModalProps> = ({
  visible,
  onCancel
}) => {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);
  const [detailModalVisible, setDetailModalVisible] = useState(false);
  const userService = new UserService();

  useEffect(() => {
    if (visible) {
      loadAuditLogs();
    }
  }, [visible]);

  const loadAuditLogs = async () => {
    setLoading(true);
    try {
      console.log('Loading audit logs...');
      const auditLogs = await userService.getDeletionAuditLogs(100);
      console.log('Audit logs received:', auditLogs);
      setLogs(auditLogs);
      
      if (auditLogs.length === 0) {
        console.log('No audit logs found. This could mean:');
        console.log('1. No users have been deleted yet');
        console.log('2. The admin_audit_logs collection does not exist');
        console.log('3. There is an issue with the Firestore query');
      }
    } catch (error) {
      console.error('Error loading audit logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const showLogDetails = (log: AuditLog) => {
    setSelectedLog(log);
    setDetailModalVisible(true);
  };

  const columns = [
    {
      title: 'Action',
      dataIndex: 'action',
      key: 'action',
      render: (action: string) => {
        const config = {
          user_deletion: { icon: <UserDeleteOutlined />, color: 'red', text: 'User Deleted' },
          user_restoration: { icon: <UndoOutlined />, color: 'green', text: 'User Restored' }
        };
        const { icon, color, text } = config[action as keyof typeof config] || { icon: null, color: 'default', text: action };
        
        return (
          <Tag color={color} icon={icon}>
            {text}
          </Tag>
        );
      }
    },
    {
      title: 'Target User',
      key: 'targetUser',
      render: (record: AuditLog) => (
        <Space direction="vertical" size={0}>
          <Text strong>{record.targetUserData?.name || 'Unknown'}</Text>
          <Text type="secondary" style={{ fontSize: '12px' }}>
            {record.targetUserData?.email || record.targetUserId}
          </Text>
        </Space>
      )
    },
    {
      title: 'Admin',
      dataIndex: 'adminId',
      key: 'adminId',
      render: (adminId: string) => (
        <Text code>{adminId}</Text>
      )
    },
    {
      title: 'Type',
      dataIndex: 'deleteType',
      key: 'deleteType',
      render: (deleteType?: string) => {
        if (!deleteType) return '-';
        return (
          <Tag color={deleteType === 'hard' ? 'red' : 'orange'}>
            {deleteType.toUpperCase()}
          </Tag>
        );
      }
    },
    {
      title: 'Timestamp',
      dataIndex: 'timestamp',
      key: 'timestamp',
      render: (timestamp: any) => {
        if (!timestamp) return '-';
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return (
          <Space direction="vertical" size={0}>
            <Text>{date.toLocaleDateString()}</Text>
            <Text type="secondary" style={{ fontSize: '12px' }}>
              {date.toLocaleTimeString()}
            </Text>
          </Space>
        );
      }
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (record: AuditLog) => (
        <Button
          type="link"
          icon={<InfoCircleOutlined />}
          onClick={() => showLogDetails(record)}
        >
          Details
        </Button>
      )
    }
  ];

  return (
    <>
      <Modal
        title={
          <Space>
            <HistoryOutlined />
            <span>User Deletion Audit Logs</span>
          </Space>
        }
        open={visible}
        onCancel={onCancel}
        width={1000}
        footer={[
          <Button key="refresh" onClick={loadAuditLogs} loading={loading}>
            Refresh
          </Button>,
          <Button key="close" type="primary" onClick={onCancel}>
            Close
          </Button>
        ]}
      >
        <Card>
          {logs.length === 0 && !loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <HistoryOutlined style={{ fontSize: '48px', color: '#d9d9d9', marginBottom: '16px' }} />
              <Title level={4} type="secondary">No Audit Logs Found</Title>
              <Text type="secondary">
                No user deletion or restoration activities have been recorded yet.
                <br />
                Audit logs will appear here after admin actions are performed.
              </Text>
            </div>
          ) : (
            <Table
              dataSource={logs}
              columns={columns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
              size="small"
            />
          )}
        </Card>
      </Modal>

      {/* Detail Modal */}
      <Modal
        title="Audit Log Details"
        open={detailModalVisible}
        onCancel={() => setDetailModalVisible(false)}
        footer={[
          <Button key="close" onClick={() => setDetailModalVisible(false)}>
            Close
          </Button>
        ]}
        width={600}
      >
        {selectedLog && (
          <Descriptions column={1} bordered size="small">
            <Descriptions.Item label="Action">
              <Tag color={selectedLog.action === 'user_deletion' ? 'red' : 'green'}>
                {selectedLog.action === 'user_deletion' ? 'User Deletion' : 'User Restoration'}
              </Tag>
            </Descriptions.Item>
            
            <Descriptions.Item label="Target User">
              {selectedLog.targetUserData?.name} ({selectedLog.targetUserData?.email})
            </Descriptions.Item>
            
            <Descriptions.Item label="User Role">
              <Tag color={selectedLog.targetUserData?.role === 'seller' ? 'blue' : 'green'}>
                {selectedLog.targetUserData?.role?.toUpperCase() || 'UNKNOWN'}
              </Tag>
            </Descriptions.Item>
            
            <Descriptions.Item label="Admin ID">
              <Text code>{selectedLog.adminId}</Text>
            </Descriptions.Item>
            
            {selectedLog.deleteType && (
              <Descriptions.Item label="Deletion Type">
                <Tag color={selectedLog.deleteType === 'hard' ? 'red' : 'orange'}>
                  {selectedLog.deleteType.toUpperCase()}
                </Tag>
              </Descriptions.Item>
            )}
            
            {selectedLog.reason && (
              <Descriptions.Item label="Reason">
                <Text>{selectedLog.reason}</Text>
              </Descriptions.Item>
            )}
            
            <Descriptions.Item label="Timestamp">
              {selectedLog.timestamp?.toDate ? 
                selectedLog.timestamp.toDate().toLocaleString() : 
                new Date(selectedLog.timestamp).toLocaleString()
              }
            </Descriptions.Item>
            
            {selectedLog.ip && (
              <Descriptions.Item label="IP Address">
                <Text code>{selectedLog.ip}</Text>
              </Descriptions.Item>
            )}
            
            {selectedLog.userAgent && (
              <Descriptions.Item label="User Agent">
                <Tooltip title={selectedLog.userAgent}>
                  <Text ellipsis style={{ maxWidth: 300 }}>
                    {selectedLog.userAgent}
                  </Text>
                </Tooltip>
              </Descriptions.Item>
            )}
          </Descriptions>
        )}
      </Modal>
    </>
  );
};

export default AuditLogsModal;

import React, { useState } from 'react';
import {
  Modal,
  Form,
  Input,
  Radio,
  Typography,
  Space,
  Divider,
  Alert,
  Checkbox,
  Button,
  Tag,
  Card
} from 'antd';
import {
  ExclamationCircleOutlined,
  DeleteOutlined,
  WarningOutlined,
  InfoCircleOutlined
} from '@ant-design/icons';
import { User } from '../types';

const { TextArea } = Input;
const { Text, Title } = Typography;

interface DeleteUserModalProps {
  visible: boolean;
  user: User | null;
  onCancel: () => void;
  onConfirm: (userId: string, deleteType: 'soft' | 'hard', reason: string) => Promise<void>;
  loading: boolean;
}

export const DeleteUserModal: React.FC<DeleteUserModalProps> = ({
  visible,
  user,
  onCancel,
  onConfirm,
  loading
}) => {
  const [form] = Form.useForm();
  const [deleteType, setDeleteType] = useState<'soft' | 'hard'>('soft');
  const [confirmChecked, setConfirmChecked] = useState(false);
  const [dangerConfirmChecked, setDangerConfirmChecked] = useState(false);

  // Reset form when modal visibility changes
  React.useEffect(() => {
    if (!visible) {
      form.resetFields();
      setConfirmChecked(false);
      setDangerConfirmChecked(false);
      setDeleteType('soft');
    }
  }, [visible, form]);

  const handleCancel = () => {
    form.resetFields();
    setConfirmChecked(false);
    setDangerConfirmChecked(false);
    setDeleteType('soft');
    onCancel();
  };

  const handleSubmit = async () => {
    console.log('=== DELETE MODAL SUBMIT ===');
    console.log('User to delete:', user);
    console.log('Delete type:', deleteType);
    console.log('confirmChecked:', confirmChecked);
    console.log('dangerConfirmChecked:', dangerConfirmChecked);
    
    // Validate checkboxes first
    if (!confirmChecked) {
      console.error('First confirmation checkbox not checked');
      return;
    }
    
    if (deleteType === 'hard' && !dangerConfirmChecked) {
      console.error('Danger confirmation checkbox not checked for hard delete');
      return;
    }
    
    try {
      const values = await form.validateFields();
      console.log('Form values:', values);
      
      if (!user) {
        console.error('No user selected');
        return;
      }

      console.log('Calling onConfirm callback with:', { userId: user.id, deleteType, reason: values.reason });
      await onConfirm(user.id, deleteType, values.reason);
      console.log('onConfirm callback completed successfully');
      
      // Reset form on success
      form.resetFields();
      setConfirmChecked(false);
      setDangerConfirmChecked(false);
      setDeleteType('soft');
      console.log('Form reset completed');
    } catch (error) {
      // Form validation failed - this is expected if fields are invalid
      if (error && typeof error === 'object' && 'errorFields' in error) {
        console.log('Form validation failed - expected behavior');
      } else {
        console.error('Error during form submission:', error);
        console.error('Error details:', error);
      }
    }
  };

  const getDeletionImpact = () => {
    if (!user) return [];

    const impacts = [];
    
    if (user.role === 'seller') {
      impacts.push('All products owned by this seller will be affected');
      impacts.push('Ongoing transactions will be cancelled');
      impacts.push('Seller rating and reviews will be preserved');
    }
    
    if (user.role === 'buyer') {
      impacts.push('Purchase history will be preserved');
      impacts.push('Ongoing orders will be cancelled');
    }

    if (deleteType === 'hard') {
      impacts.push('⚠️ User data will be permanently removed');
      impacts.push('⚠️ This action cannot be undone');
    } else {
      impacts.push('✅ User will be deactivated (can be restored later)');
      impacts.push('✅ Data will be preserved for compliance');
    }

    return impacts;
  };

  return (
    <Modal
      title={
        <Space>
          <DeleteOutlined style={{ color: '#ff4d4f' }} />
          <span>Delete User Account</span>
        </Space>
      }
      open={visible}
      onCancel={handleCancel}
      width={600}
      footer={[
        <Button key="cancel" onClick={handleCancel}>
          Cancel
        </Button>,
        <Button
          key="delete"
          type="primary"
          danger
          loading={loading}
          disabled={!confirmChecked || (deleteType === 'hard' && !dangerConfirmChecked)}
          onClick={handleSubmit}
          icon={<DeleteOutlined />}
        >
          {deleteType === 'soft' ? 'Deactivate User' : 'Permanently Delete'}
        </Button>
      ]}
    >
      {user && (
        <Form form={form} layout="vertical">
          {/* User Information */}
          <Card size="small" style={{ marginBottom: 16 }}>
            <Title level={5}>User Information</Title>
            <Space direction="vertical" size={4}>
              <Text><strong>Name:</strong> {user.name}</Text>
              <Text><strong>Email:</strong> {user.email}</Text>
              <Text><strong>Role:</strong> <Tag color={user.role === 'seller' ? 'blue' : 'green'}>{user.role?.toUpperCase()}</Tag></Text>
              <Text><strong>Status:</strong> <Tag color={user.status === 'active' ? 'green' : 'orange'}>{user.status?.toUpperCase()}</Tag></Text>
            </Space>
          </Card>

          {/* Deletion Type */}
          <Form.Item
            name="deleteType"
            label="Deletion Type"
            initialValue="soft"
          >
            <Radio.Group 
              value={deleteType} 
              onChange={(e) => setDeleteType(e.target.value)}
            >
              <Space direction="vertical">
                <Radio value="soft">
                  <Space>
                    <InfoCircleOutlined style={{ color: '#1890ff' }} />
                    <strong>Soft Delete (Recommended)</strong>
                  </Space>
                  <div style={{ marginLeft: 20, marginTop: 4 }}>
                    <Text type="secondary">
                      Deactivate user account while preserving data for compliance and potential restoration
                    </Text>
                  </div>
                </Radio>
                <Radio value="hard">
                  <Space>
                    <WarningOutlined style={{ color: '#ff4d4f' }} />
                    <strong>Hard Delete (Permanent)</strong>
                  </Space>
                  <div style={{ marginLeft: 20, marginTop: 4 }}>
                    <Text type="secondary">
                      Permanently remove user data (cannot be undone)
                    </Text>
                  </div>
                </Radio>
              </Space>
            </Radio.Group>
          </Form.Item>

          <Divider />

          {/* Impact Assessment */}
          <Alert
            message="Deletion Impact"
            description={
              <ul style={{ marginBottom: 0, paddingLeft: 20 }}>
                {getDeletionImpact().map((impact, index) => (
                  <li key={index}>{impact}</li>
                ))}
              </ul>
            }
            type={deleteType === 'hard' ? 'error' : 'warning'}
            showIcon
            style={{ marginBottom: 16 }}
          />

          {/* Reason */}
          <Form.Item
            name="reason"
            label="Deletion Reason"
            rules={[
              { required: true, message: 'Please provide a reason for deletion' },
              { min: 10, message: 'Reason must be at least 10 characters' }
            ]}
          >
            <TextArea
              rows={3}
              placeholder="Provide a detailed reason for this deletion (required for audit trail)..."
            />
          </Form.Item>

          {/* Confirmations */}
          <Space direction="vertical" style={{ width: '100%' }}>
            <Checkbox
              checked={confirmChecked}
              onChange={(e) => setConfirmChecked(e.target.checked)}
            >
              I understand the consequences of this action and have provided a valid reason
            </Checkbox>

            {deleteType === 'hard' && (
              <Checkbox
                checked={dangerConfirmChecked}
                onChange={(e) => setDangerConfirmChecked(e.target.checked)}
              >
                <Text type="danger">
                  <strong>I understand this is a permanent action that cannot be undone</strong>
                </Text>
              </Checkbox>
            )}
          </Space>

          {deleteType === 'hard' && (
            <Alert
              message="Warning: Permanent Deletion"
              description="This action will permanently delete all user data and cannot be reversed. Consider using soft delete instead for compliance and data recovery purposes."
              type="error"
              showIcon
              style={{ marginTop: 16 }}
            />
          )}
        </Form>
      )}
    </Modal>
  );
};

export default DeleteUserModal;

import React, { useState, useEffect } from 'react';
import { Card, Table, Tag, Button, Modal, Input, Space, Select, message, Tabs } from 'antd';
import { CommentOutlined, EyeOutlined, CheckCircleOutlined, CloseCircleOutlined } from '@ant-design/icons';
import { collection, query, getDocs, doc, updateDoc, addDoc, Timestamp, orderBy } from 'firebase/firestore';
import { db } from '../services/firebase';

const { TextArea } = Input;
const { TabPane } = Tabs;

interface Feedback {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  subject: string;
  message: string;
  type: 'issue' | 'feedback' | 'complaint' | 'suggestion';
  status: 'pending' | 'in-progress' | 'resolved' | 'closed';
  priority: 'low' | 'medium' | 'high';
  createdAt: any;
  response?: string;
  respondedAt?: any;
  respondedBy?: string;
}

export const UserFeedbackReports: React.FC = () => {
  const [feedbacks, setFeedbacks] = useState<Feedback[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFeedback, setSelectedFeedback] = useState<Feedback | null>(null);
  const [viewModalVisible, setViewModalVisible] = useState(false);
  const [responseText, setResponseText] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');

  useEffect(() => {
    loadFeedbacks();
  }, []);

  const loadFeedbacks = async () => {
    setLoading(true);
    try {
      // Try with orderBy first
      let feedbackQuery;
      let snapshot;
      
      try {
        feedbackQuery = query(
          collection(db, 'user_feedback'),
          orderBy('createdAt', 'desc')
        );
        snapshot = await getDocs(feedbackQuery);
      } catch (indexError: any) {
        // If index is missing, fetch without ordering
        console.log('Fetching without order (index may be missing):', indexError.message);
        snapshot = await getDocs(collection(db, 'user_feedback'));
      }
      
      const feedbackData: Feedback[] = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Feedback));

      // Sort in memory if we couldn't use orderBy
      feedbackData.sort((a, b) => {
        const aTime = a.createdAt?.toMillis?.() || 0;
        const bTime = b.createdAt?.toMillis?.() || 0;
        return bTime - aTime;
      });

      setFeedbacks(feedbackData);
      
      if (feedbackData.length === 0) {
        message.info('No feedback submissions found');
      } else {
        message.success(`Loaded ${feedbackData.length} feedback items`);
      }
    } catch (error: any) {
      console.error('Error loading feedbacks:', error);
      message.error(`Failed to load feedbacks: ${error.message || 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  const handleViewFeedback = (feedback: Feedback) => {
    setSelectedFeedback(feedback);
    setResponseText(feedback.response || '');
    setViewModalVisible(true);
  };

  const handleUpdateStatus = async (feedbackId: string, newStatus: string) => {
    try {
      await updateDoc(doc(db, 'user_feedback', feedbackId), {
        status: newStatus,
        updatedAt: Timestamp.now()
      });
      message.success('Status updated successfully');
      loadFeedbacks();
    } catch (error) {
      console.error('Error updating status:', error);
      message.error('Failed to update status');
    }
  };

  const handleSubmitResponse = async () => {
    if (!selectedFeedback || !responseText.trim()) {
      message.warning('Please enter a response');
      return;
    }

    try {
      await updateDoc(doc(db, 'user_feedback', selectedFeedback.id), {
        response: responseText,
        respondedAt: Timestamp.now(),
        respondedBy: 'admin',
        status: 'resolved',
        updatedAt: Timestamp.now()
      });

      // Send notification to user - using 'notifications' collection
      await addDoc(collection(db, 'notifications'), {
        userId: selectedFeedback.userId,
        title: 'Response to Your Feedback',
        message: `Admin has responded to your ${selectedFeedback.type}: ${selectedFeedback.subject}`,
        type: 'feedback_response',
        read: false,
        createdAt: Timestamp.now()
      });

      message.success('Response sent successfully');
      setViewModalVisible(false);
      loadFeedbacks();
    } catch (error) {
      console.error('Error submitting response:', error);
      message.error('Failed to send response');
    }
  };

  const getTypeColor = (type: string) => {
    const colors: any = {
      issue: 'red',
      complaint: 'orange',
      feedback: 'blue',
      suggestion: 'green'
    };
    return colors[type] || 'default';
  };

  const getStatusColor = (status: string) => {
    const colors: any = {
      pending: 'orange',
      'in-progress': 'blue',
      resolved: 'green',
      closed: 'default'
    };
    return colors[status] || 'default';
  };

  const getPriorityColor = (priority: string) => {
    const colors: any = {
      low: 'green',
      medium: 'orange',
      high: 'red'
    };
    return colors[priority] || 'default';
  };

  const filteredFeedbacks = filterStatus === 'all' 
    ? feedbacks 
    : feedbacks.filter(f => f.status === filterStatus);

  const columns = [
    {
      title: 'Date',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 120,
      render: (date: any) => {
        if (!date) return '-';
        const timestamp = date.toDate ? date.toDate() : new Date(date);
        return timestamp.toLocaleDateString();
      }
    },
    {
      title: 'User',
      dataIndex: 'userName',
      key: 'userName',
      render: (text: string, record: Feedback) => (
        <div>
          <div style={{ fontWeight: 500 }}>{text}</div>
          <div style={{ fontSize: '12px', color: '#888' }}>{record.userEmail}</div>
        </div>
      )
    },
    {
      title: 'Type',
      dataIndex: 'type',
      key: 'type',
      width: 100,
      render: (type: string) => (
        <Tag color={getTypeColor(type)}>{type.toUpperCase()}</Tag>
      )
    },
    {
      title: 'Subject',
      dataIndex: 'subject',
      key: 'subject',
      ellipsis: true
    },
    {
      title: 'Priority',
      dataIndex: 'priority',
      key: 'priority',
      width: 100,
      render: (priority: string) => (
        <Tag color={getPriorityColor(priority)}>{priority.toUpperCase()}</Tag>
      )
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      width: 120,
      render: (status: string, record: Feedback) => (
        <Select
          value={status}
          style={{ width: '100%' }}
          onChange={(value) => handleUpdateStatus(record.id, value)}
          size="small"
        >
          <Select.Option value="pending">Pending</Select.Option>
          <Select.Option value="in-progress">In Progress</Select.Option>
          <Select.Option value="resolved">Resolved</Select.Option>
          <Select.Option value="closed">Closed</Select.Option>
        </Select>
      )
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_: any, record: Feedback) => (
        <Button
          type="primary"
          size="small"
          icon={<EyeOutlined />}
          onClick={() => handleViewFeedback(record)}
        >
          View
        </Button>
      )
    }
  ];

  const stats = {
    total: feedbacks.length,
    pending: feedbacks.filter(f => f.status === 'pending').length,
    inProgress: feedbacks.filter(f => f.status === 'in-progress').length,
    resolved: feedbacks.filter(f => f.status === 'resolved').length,
    highPriority: feedbacks.filter(f => f.priority === 'high').length
  };

  return (
    <div style={{ padding: '24px' }}>
      <h2 style={{ marginBottom: '24px' }}>
        <CommentOutlined /> User Feedback & Reports
      </h2>

      {/* Statistics Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '16px', marginBottom: '24px' }}>
        <Card>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#1890ff' }}>{stats.total}</div>
            <div style={{ color: '#888' }}>Total Feedbacks</div>
          </div>
        </Card>
        <Card>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#faad14' }}>{stats.pending}</div>
            <div style={{ color: '#888' }}>Pending</div>
          </div>
        </Card>
        <Card>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#1890ff' }}>{stats.inProgress}</div>
            <div style={{ color: '#888' }}>In Progress</div>
          </div>
        </Card>
        <Card>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#52c41a' }}>{stats.resolved}</div>
            <div style={{ color: '#888' }}>Resolved</div>
          </div>
        </Card>
        <Card>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#ff4d4f' }}>{stats.highPriority}</div>
            <div style={{ color: '#888' }}>High Priority</div>
          </div>
        </Card>
      </div>

      {/* Feedbacks Table */}
      <Card>
        <Space style={{ marginBottom: '16px' }}>
          <span>Filter by Status:</span>
          <Select value={filterStatus} onChange={setFilterStatus} style={{ width: 150 }}>
            <Select.Option value="all">All</Select.Option>
            <Select.Option value="pending">Pending</Select.Option>
            <Select.Option value="in-progress">In Progress</Select.Option>
            <Select.Option value="resolved">Resolved</Select.Option>
            <Select.Option value="closed">Closed</Select.Option>
          </Select>
        </Space>

        <Table
          columns={columns}
          dataSource={filteredFeedbacks}
          rowKey="id"
          loading={loading}
          pagination={{ pageSize: 10 }}
        />
      </Card>

      {/* View/Respond Modal */}
      <Modal
        title="Feedback Details"
        visible={viewModalVisible}
        onCancel={() => setViewModalVisible(false)}
        width={700}
        footer={[
          <Button key="close" onClick={() => setViewModalVisible(false)}>
            Close
          </Button>,
          <Button
            key="respond"
            type="primary"
            onClick={handleSubmitResponse}
            disabled={selectedFeedback?.status === 'resolved'}
          >
            Send Response
          </Button>
        ]}
      >
        {selectedFeedback && (
          <div>
            <div style={{ marginBottom: '16px' }}>
              <strong>User:</strong> {selectedFeedback.userName} ({selectedFeedback.userEmail})
            </div>
            <div style={{ marginBottom: '16px' }}>
              <strong>Type:</strong>{' '}
              <Tag color={getTypeColor(selectedFeedback.type)}>{selectedFeedback.type.toUpperCase()}</Tag>
              <strong style={{ marginLeft: '16px' }}>Priority:</strong>{' '}
              <Tag color={getPriorityColor(selectedFeedback.priority)}>{selectedFeedback.priority.toUpperCase()}</Tag>
              <strong style={{ marginLeft: '16px' }}>Status:</strong>{' '}
              <Tag color={getStatusColor(selectedFeedback.status)}>{selectedFeedback.status.toUpperCase()}</Tag>
            </div>
            <div style={{ marginBottom: '16px' }}>
              <strong>Subject:</strong> {selectedFeedback.subject}
            </div>
            <div style={{ marginBottom: '16px' }}>
              <strong>Message:</strong>
              <div style={{ 
                marginTop: '8px', 
                padding: '12px', 
                background: '#f5f5f5', 
                borderRadius: '4px',
                whiteSpace: 'pre-wrap'
              }}>
                {selectedFeedback.message}
              </div>
            </div>
            
            {selectedFeedback.response && (
              <div style={{ marginBottom: '16px' }}>
                <strong>Previous Response:</strong>
                <div style={{ 
                  marginTop: '8px', 
                  padding: '12px', 
                  background: '#e6f7ff', 
                  borderRadius: '4px',
                  whiteSpace: 'pre-wrap'
                }}>
                  {selectedFeedback.response}
                </div>
              </div>
            )}

            <div>
              <strong>Admin Response:</strong>
              <TextArea
                value={responseText}
                onChange={(e) => setResponseText(e.target.value)}
                placeholder="Enter your response to the user..."
                rows={4}
                style={{ marginTop: '8px' }}
                disabled={selectedFeedback.status === 'resolved'}
              />
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

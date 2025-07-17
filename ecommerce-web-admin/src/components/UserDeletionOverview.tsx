import React from 'react';
import { 
  Card, 
  Typography, 
  Space, 
  Tag, 
  List,
  Divider,
  Alert
} from 'antd';
import { 
  DeleteOutlined, 
  HistoryOutlined, 
  UndoOutlined,
  CheckCircleOutlined
} from '@ant-design/icons';

const { Title, Paragraph } = Typography;

export const UserDeletionOverview: React.FC = () => {
  const features = [
    {
      icon: <DeleteOutlined style={{ color: '#ff4d4f' }} />,
      title: 'Soft & Hard Deletion',
      description: 'Choose between reversible soft deletion or permanent hard deletion',
      benefits: ['Data recovery option', 'Compliance ready', 'Flexible approach', 'Audit friendly']
    },
    {
      icon: <HistoryOutlined style={{ color: '#1890ff' }} />,
      title: 'Comprehensive Audit Trail',
      description: 'Every deletion action is logged with detailed information for accountability',
      benefits: ['Admin accountability', 'Timestamp tracking', 'Reason documentation', 'IP & browser logging']
    },
    {
      icon: <UndoOutlined style={{ color: '#722ed1' }} />,
      title: 'User Restoration',
      description: 'Ability to restore soft-deleted users with full data integrity',
      benefits: ['Quick recovery', 'Data integrity', 'Business continuity', 'Customer satisfaction']
    }
  ];

  const safeguards = [
    'Multi-step confirmation process',
    'Mandatory deletion reason',
    'Impact assessment display',
    'Different confirmation levels for soft vs hard delete',
    'Automatic handling of related data (products, transactions)',
    'Admin authentication required',
    'Audit trail generation'
  ];

  return (
    <div style={{ padding: '24px' }}>
      <Card>
        <Title level={2}>
          <DeleteOutlined style={{ marginRight: 8 }} />
          Professional User Deletion System
        </Title>
        
        <Paragraph>
          Our admin dashboard implements a comprehensive user deletion system designed with 
          enterprise-grade security, compliance, and data integrity in mind.
        </Paragraph>

        <Alert
          message="Enterprise-Grade User Management"
          description="This deletion system is designed to meet professional standards for data handling, compliance, and user management."
          type="info"
          showIcon
          style={{ marginBottom: 24 }}
        />

        <Divider />

        <Title level={3}>Key Features</Title>
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          {features.map((feature, index) => (
            <Card key={index} size="small">
              <Space align="start">
                {feature.icon}
                <div>
                  <Title level={4} style={{ margin: 0 }}>{feature.title}</Title>
                  <Paragraph style={{ margin: '8px 0' }}>{feature.description}</Paragraph>
                  <Space wrap>
                    {feature.benefits.map((benefit, i) => (
                      <Tag key={i} color="blue">{benefit}</Tag>
                    ))}
                  </Space>
                </div>
              </Space>
            </Card>
          ))}
        </Space>

        <Divider />

        <Title level={3}>
          <CheckCircleOutlined style={{ color: '#52c41a', marginRight: 8 }} />
          Built-in Safeguards
        </Title>
        
        <List
          dataSource={safeguards}
          renderItem={(item) => (
            <List.Item>
              <CheckCircleOutlined style={{ color: '#52c41a', marginRight: 8 }} />
              {item}
            </List.Item>
          )}
        />

        <Divider />

        <Card style={{ backgroundColor: '#f6f8fa' }}>
          <Title level={4}>Professional Implementation Highlights</Title>
          <ul>
            <li><strong>Data Relationships:</strong> Automatically handles seller products and buyer transactions</li>
            <li><strong>Compliance Ready:</strong> Supports GDPR and other data protection regulations</li>
            <li><strong>Audit Trail:</strong> Complete action logging for security and compliance</li>
            <li><strong>User Experience:</strong> Clear confirmation dialogs with impact assessment</li>
            <li><strong>Error Handling:</strong> Comprehensive error management and user feedback</li>
            <li><strong>Scalability:</strong> Efficient batch operations for related data handling</li>
          </ul>
        </Card>
      </Card>
    </div>
  );
};

export default UserDeletionOverview;
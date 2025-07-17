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
  Row,
  Col,
  Statistic
} from 'antd';
import { 
  BellOutlined, 
  SendOutlined
} from '@ant-design/icons';

const { Title, Paragraph } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface AnnouncementFormData {
  title: string;
  message: string;
  targetRole: 'all' | 'buyer' | 'seller';
}

export const AnnouncementManagement: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  const handleSendAnnouncement = async (values: AnnouncementFormData) => {
    try {
      setLoading(true);
      
      // TODO: Implement actual announcement sending
      console.log('Sending announcement:', values);
      
      message.success('Announcement sent successfully!');
      form.resetFields();
    } catch (error) {
      console.error('Error sending announcement:', error);
      message.error('Failed to send announcement');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: '24px' }}>
      <Card>
        <Title level={2}>
          <BellOutlined style={{ marginRight: 8 }} />
          Announcement Management
        </Title>
        
        <Paragraph>
          Send system-wide announcements to keep your users informed about important updates, promotions, and system changes.
        </Paragraph>

        {/* Statistics Overview */}
        <Row gutter={16} style={{ marginBottom: 24 }}>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic
                title="Total Notifications Sent"
                value={0}
                prefix={<BellOutlined />}
              />
            </Card>
          </Col>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic
                title="Active Announcements"
                value={0}
                prefix={<BellOutlined />}
              />
            </Card>
          </Col>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic
                title="Total Recipients"
                value={0}
                prefix={<BellOutlined />}
              />
            </Card>
          </Col>
        </Row>

        {/* Create Announcement Form */}
        <Card title="Create Announcement" style={{ marginTop: 24 }}>
          <Form
            form={form}
            layout="vertical"
            onFinish={handleSendAnnouncement}
          >
            <Form.Item
              name="title"
              label="Announcement Title"
              rules={[
                { required: true, message: 'Please enter announcement title' },
                { max: 100, message: 'Title must be less than 100 characters' }
              ]}
            >
              <Input placeholder="Enter announcement title" />
            </Form.Item>

            <Form.Item
              name="message"
              label="Announcement Message"
              rules={[
                { required: true, message: 'Please enter announcement message' },
                { max: 500, message: 'Message must be less than 500 characters' }
              ]}
            >
              <TextArea 
                rows={4} 
                placeholder="Enter announcement message"
                showCount
                maxLength={500}
              />
            </Form.Item>

            <Form.Item
              name="targetRole"
              label="Target Audience"
              rules={[{ required: true, message: 'Please select target audience' }]}
              initialValue="all"
            >
              <Select placeholder="Select target audience">
                <Option value="all">All Users</Option>
                <Option value="buyer">Buyers Only</Option>
                <Option value="seller">Sellers Only</Option>
              </Select>
            </Form.Item>

            <Form.Item>
              <Space>
                <Button type="primary" htmlType="submit" loading={loading} icon={<SendOutlined />}>
                  Send Announcement
                </Button>
                <Button onClick={() => form.resetFields()}>
                  Clear Form
                </Button>
              </Space>
            </Form.Item>
          </Form>
        </Card>
      </Card>
    </div>
  );
};

export default AnnouncementManagement;
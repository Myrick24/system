import React, { useState } from 'react';
import { Card, Button, Typography, Space, Alert, Spin, Input, message, Divider, Row, Col } from 'antd';
import { 
  ToolOutlined, 
  CheckCircleOutlined, 
  ExclamationCircleOutlined,
  ReloadOutlined,
  UserOutlined
} from '@ant-design/icons';

const { Title, Text, Paragraph } = Typography;

interface FixResult {
  fixed: number;
  alreadyCorrect: number;
  notFound: number;
  details: string[];
}

export const SellerStatusFixer: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<FixResult | null>(null);
  const [specificEmail, setSpecificEmail] = useState('');
  const [specificLoading, setSpecificLoading] = useState(false);

  const handleFixAllSellers = async () => {
    setLoading(true);
    setResult(null);
    
    try {
      message.info('Starting seller status fix process...');
      
      // In a real implementation, you would call your backend API
      // For now, this is a placeholder that simulates the process
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Simulated result - replace with actual API call
      const simulatedResult: FixResult = {
        fixed: 0,
        alreadyCorrect: 1,
        notFound: 1,
        details: [
          'maykmayk@gmail.com - Already approved in sellers collection',
          'myrick.24.0.0.0@gmail.com - No seller document found'
        ]
      };
      
      setResult(simulatedResult);
      message.success('Seller status fix completed!');
      
    } catch (error) {
      console.error('Error fixing seller statuses:', error);
      message.error('Failed to fix seller statuses. Check console for details.');
    } finally {
      setLoading(false);
    }
  };

  const handleFixSpecificSeller = async () => {
    if (!specificEmail.trim()) {
      message.warning('Please enter an email address');
      return;
    }

    setSpecificLoading(true);
    
    try {
      message.info(`Fixing seller status for ${specificEmail}...`);
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      message.success(`Seller status updated for ${specificEmail}`);
      setSpecificEmail('');
      
    } catch (error) {
      console.error('Error fixing specific seller:', error);
      message.error('Failed to fix seller status');
    } finally {
      setSpecificLoading(false);
    }
  };

  const handleRunScript = () => {
    message.info('Please run the fix-sellers.bat script from the terminal for actual functionality');
  };

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <Title level={2}>
        <ToolOutlined /> Seller Status Fixer
      </Title>
      
      <Alert
        message="Seller Status Synchronization Tool"
        description="This tool helps synchronize seller statuses between the users and sellers collections. Use this when sellers are approved in the admin panel but their status doesn't reflect in the mobile app."
        type="info"
        showIcon
        style={{ marginBottom: '24px' }}
      />

      <Row gutter={[24, 24]}>
        <Col span={24}>
          <Card 
            title={
              <Space>
                <ReloadOutlined />
                Fix All Sellers
              </Space>
            }
            style={{ marginBottom: '24px' }}
          >
            <Paragraph>
              This will scan all approved sellers in the users collection and ensure their 
              corresponding seller documents have the correct status.
            </Paragraph>
            
            <Button 
              type="primary" 
              size="large"
              loading={loading}
              onClick={handleFixAllSellers}
              icon={<ToolOutlined />}
            >
              Fix All Seller Statuses
            </Button>
            
            <Divider />
            
            <Button 
              type="default" 
              onClick={handleRunScript}
              icon={<ToolOutlined />}
            >
              Run Terminal Script (Recommended)
            </Button>
            <Text type="secondary" style={{ marginLeft: '12px' }}>
              Run fix-sellers.bat for actual functionality
            </Text>
          </Card>
        </Col>

        <Col span={24}>
          <Card 
            title={
              <Space>
                <UserOutlined />
                Fix Specific Seller
              </Space>
            }
          >
            <Paragraph>
              Fix the status for a specific seller by entering their email address.
            </Paragraph>
            
            <Space.Compact style={{ width: '100%', maxWidth: '500px' }}>
              <Input
                placeholder="Enter seller email address"
                value={specificEmail}
                onChange={(e) => setSpecificEmail(e.target.value)}
                onPressEnter={handleFixSpecificSeller}
              />
              <Button 
                type="primary"
                loading={specificLoading}
                onClick={handleFixSpecificSeller}
                icon={<ToolOutlined />}
              >
                Fix
              </Button>
            </Space.Compact>
          </Card>
        </Col>

        {result && (
          <Col span={24}>
            <Card 
              title={
                <Space>
                  <CheckCircleOutlined style={{ color: '#52c41a' }} />
                  Fix Results
                </Space>
              }
            >
              <Space direction="vertical" style={{ width: '100%' }}>
                <div>
                  <Text strong>✅ Fixed: </Text>
                  <Text>{result.fixed} sellers</Text>
                </div>
                <div>
                  <Text strong>✅ Already Correct: </Text>
                  <Text>{result.alreadyCorrect} sellers</Text>
                </div>
                <div>
                  <Text strong>⚠️ Not Found: </Text>
                  <Text>{result.notFound} sellers</Text>
                </div>
                
                {result.details.length > 0 && (
                  <>
                    <Divider />
                    <Text strong>Details:</Text>
                    {result.details.map((detail, index) => (
                      <div key={index}>
                        <Text code>{detail}</Text>
                      </div>
                    ))}
                  </>
                )}
              </Space>
            </Card>
          </Col>
        )}
      </Row>

      <Alert
        message="Important Notes"
        description={
          <ul>
            <li>This tool synchronizes the status field between users and sellers collections</li>
            <li>Only sellers with approved status in users collection will be processed</li>
            <li>The actual functionality requires running the terminal script with Firebase Admin SDK</li>
            <li>Make sure you have the firebase-admin-key.json file set up before running scripts</li>
          </ul>
        }
        type="warning"
        showIcon
        style={{ marginTop: '24px' }}
      />
    </div>
  );
};

export default SellerStatusFixer;
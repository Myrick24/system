import React, { useState } from 'react';
import { Button, Card, Typography, message, Spin, Space, Divider } from 'antd';
import { AdminService } from '../services/adminService';
import { UserService } from '../services/userService';

const { Title, Paragraph } = Typography;

export const FirestoreTest: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [auditLoading, setAuditLoading] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<string>('Not tested');
  const [auditStatus, setAuditStatus] = useState<string>('Not tested');
  const adminService = new AdminService();
  const userService = new UserService();

  const testFirestoreConnection = async () => {
    setLoading(true);
    try {
      const stats = await adminService.getDashboardStats();
      setConnectionStatus(`✅ Connected! Found ${stats.totalUsers} users in database`);
      message.success('Firestore connection successful!');
    } catch (error) {
      console.error('Firestore connection failed:', error);
      setConnectionStatus(`❌ Connection failed: ${error}`);
      message.error('Firestore connection failed');
    } finally {
      setLoading(false);
    }
  };

  const testAuditLogs = async () => {
    setAuditLoading(true);
    try {
      console.log('Testing audit logs...');
      const auditLogs = await userService.getDeletionAuditLogs(10);
      setAuditStatus(`✅ Audit system working! Found ${auditLogs.length} audit logs`);
      
      if (auditLogs.length > 0) {
        console.log('Sample audit logs:', auditLogs.slice(0, 3));
        message.success(`Found ${auditLogs.length} audit logs`);
      } else {
        message.info('No audit logs found - this is normal if no users have been deleted yet');
      }
    } catch (error) {
      console.error('Audit logs test failed:', error);
      setAuditStatus(`❌ Audit test failed: ${error}`);
      message.error('Audit logs test failed');
    } finally {
      setAuditLoading(false);
    }
  };

  const createTestAuditLog = async () => {
    setAuditLoading(true);
    try {
      console.log('Creating test audit log...');
      const result = await userService.createTestAuditLog();
      
      if (result.success) {
        setAuditStatus(`✅ Test audit log created successfully!`);
        message.success(result.message);
      } else {
        setAuditStatus(`❌ Failed to create test audit log: ${result.message}`);
        message.error(result.message);
      }
    } catch (error) {
      console.error('Test audit log creation failed:', error);
      setAuditStatus(`❌ Test failed: ${error}`);
      message.error('Test audit log creation failed');
    } finally {
      setAuditLoading(false);
    }
  };

  return (
    <div style={{ padding: '24px' }}>
      <Card>
        <Title level={2}>Firestore & Audit System Test</Title>
        <Paragraph>
          This component tests the connection to your Firestore database and verifies 
          that the audit logging system is working correctly for user deletions.
        </Paragraph>
        
        <Paragraph type="secondary">
          <strong>Instructions:</strong>
          <ol>
            <li>First, test the Firestore connection to ensure database access</li>
            <li>Then test the audit logs system to check for existing logs</li>
            <li>Optionally, create a test audit log to verify write permissions</li>
            <li>After testing, go to User Management → View Audit Logs to see results</li>
          </ol>
        </Paragraph>
        
        <div style={{ margin: '20px 0' }}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <Button 
              type="primary" 
              onClick={testFirestoreConnection}
              loading={loading}
              size="large"
              block
            >
              {loading ? 'Testing Connection...' : 'Test Firestore Connection'}
            </Button>
            
            <Button 
              type="default" 
              onClick={testAuditLogs}
              loading={auditLoading}
              size="large"
              block
            >
              {auditLoading ? 'Testing Audit Logs...' : 'Test Audit Logs System'}
            </Button>
            
            <Button 
              type="dashed" 
              onClick={createTestAuditLog}
              loading={auditLoading}
              size="large"
              block
            >
              {auditLoading ? 'Creating Test Log...' : 'Create Test Audit Log'}
            </Button>
          </Space>
        </div>

        <Divider />

        <div style={{ marginTop: '20px' }}>
          <div style={{ marginBottom: '10px' }}>
            <strong>Database Connection: </strong>
            {loading ? <Spin size="small" /> : connectionStatus}
          </div>
          
          <div>
            <strong>Audit Logs System: </strong>
            {auditLoading ? <Spin size="small" /> : auditStatus}
          </div>
        </div>

        <Divider />

        <Title level={3}>Audit Logs Test</Title>
        <Paragraph>
          This function tests if the audit logs are being recorded properly in the system.
        </Paragraph>

        <div style={{ margin: '20px 0' }}>
          <Button 
            type="primary" 
            onClick={testAuditLogs}
            loading={auditLoading}
            size="large"
          >
            {auditLoading ? 'Testing Audit Logs...' : 'Test Audit Logs'}
          </Button>
        </div>

        <div style={{ marginTop: '20px' }}>
          <strong>Status: </strong>
          {auditLoading ? <Spin size="small" /> : auditStatus}
        </div>
      </Card>
    </div>
  );
};

export default FirestoreTest;
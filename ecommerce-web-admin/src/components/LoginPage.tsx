import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, Typography, Alert, Spin } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

const { Title } = Typography;

interface LoginFormValues {
  email: string;
  password: string;
}

export const LoginPage: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { login, user, isAdmin } = useAuth();
  const navigate = useNavigate();

  // Redirect if already authenticated
  useEffect(() => {
    if (user && isAdmin) {
      console.log('User already authenticated, redirecting to dashboard');
      navigate('/', { replace: true });
    }
  }, [user, isAdmin, navigate]);

  const onFinish = async (values: LoginFormValues) => {
    setLoading(true);
    setError(null);

    try {
      await login(values.email, values.password);
      console.log('Login completed, waiting for auth state change...');
      // Don't navigate here - let the useEffect handle it after auth state changes
    } catch (error: any) {
      setError(error.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ 
      height: '100vh', 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
    }}>
      <Card style={{ width: 400, boxShadow: '0 8px 32px rgba(0,0,0,0.1)' }}>
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <Title level={2} style={{ color: '#1890ff' }}>
            Admin Dashboard
          </Title>
          <p style={{ color: '#666' }}>
            E-commerce Management System
          </p>
        </div>

        {error && (
          <Alert
            message="Login Error"
            description={error}
            type="error"
            showIcon
            style={{ marginBottom: 16 }}
            action={
              <Button 
                size="small" 
                type="link" 
                onClick={() => window.open('/debug', '_blank')}
              >
                Debug
              </Button>
            }
            closable
            onClose={() => setError(null)}
          />
        )}

        <Form
          name="login"
          onFinish={onFinish}
          layout="vertical"
          size="large"
        >
          <Form.Item
            name="email"
            label="Email"
            rules={[
              { required: true, message: 'Please input your email!' },
              { type: 'email', message: 'Please enter a valid email!' }
            ]}
          >
            <Input 
              prefix={<UserOutlined />} 
              placeholder="admin@example.com" 
            />
          </Form.Item>

          <Form.Item
            name="password"
            label="Password"
            rules={[{ required: true, message: 'Please input your password!' }]}
          >
            <Input.Password 
              prefix={<LockOutlined />} 
              placeholder="Password" 
            />
          </Form.Item>

          <Form.Item>
            <Button 
              type="primary" 
              htmlType="submit" 
              style={{ width: '100%' }}
              disabled={loading}
            >
              {loading ? <Spin size="small" /> : 'Sign In'}
            </Button>
          </Form.Item>
        </Form>

        <div style={{ textAlign: 'center', marginTop: 16, color: '#666' }}>
          <small>
            Use your admin credentials to access the dashboard
          </small>
        </div>
      </Card>
    </div>
  );
};

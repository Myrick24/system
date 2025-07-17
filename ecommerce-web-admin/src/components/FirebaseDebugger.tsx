import React, { useState, useEffect } from 'react';
import { Card, Button, Input, Typography, Space, Alert, Divider } from 'antd';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth, db } from '../services/firebase';

const { Title, Text } = Typography;

export const FirebaseDebugger: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<any>(null);

  useEffect(() => {
    checkFirebaseConnection();
  }, []);

  const checkFirebaseConnection = async () => {
    try {
      // Test Firebase connection
      const testQuery = query(collection(db, 'users'), where('email', '==', 'test@test.com'));
      await getDocs(testQuery);
      setConnectionStatus({ 
        success: true, 
        message: 'Firebase connection successful',
        timestamp: new Date().toLocaleString()
      });
    } catch (error: any) {
      setConnectionStatus({ 
        success: false, 
        message: `Firebase connection failed: ${error.message}`,
        error: error.code,
        timestamp: new Date().toLocaleString()
      });
    }
  };

  const testNetworkConnectivity = async () => {
    setLoading(true);
    try {
      // Test general internet connectivity
      const response = await fetch('https://www.google.com/favicon.ico', { 
        mode: 'no-cors',
        cache: 'no-cache'
      });
      
      // Test Firebase endpoints
      const firebaseTest = await fetch('https://e-commerce-app-5cda8.firebaseapp.com/', {
        mode: 'no-cors',
        cache: 'no-cache'
      });

      setResult({
        success: true,
        message: 'Network connectivity test passed',
        details: {
          internet: 'Connected',
          firebase: 'Reachable',
          timestamp: new Date().toLocaleString()
        }
      });
    } catch (error: any) {
      setResult({
        success: false,
        message: 'Network connectivity test failed',
        error: error.message,
        suggestions: [
          'Check your internet connection',
          'Disable VPN if using one',
          'Check firewall settings',
          'Try using a different network'
        ]
      });
    } finally {
      setLoading(false);
    }
  };

  const testFirebaseAuth = async () => {
    if (!email || !password) {
      setResult({ error: 'Please enter both email and password' });
      return;
    }

    setLoading(true);
    try {
      console.log('Testing Firebase Auth...');
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      setResult({
        success: true,
        message: 'Firebase Authentication successful!',
        userData: {
          uid: userCredential.user.uid,
          email: userCredential.user.email,
          timestamp: new Date().toLocaleString()
        }
      });
    } catch (error: any) {
      console.error('Firebase Auth Error:', error);
      setResult({
        success: false,
        message: 'Firebase Authentication failed',
        error: error.code,
        errorMessage: error.message,
        suggestions: getErrorSuggestions(error.code)
      });
    } finally {
      setLoading(false);
    }
  };

  const getErrorSuggestions = (errorCode: string) => {
    switch (errorCode) {
      case 'auth/network-request-failed':
        return [
          'Check your internet connection',
          'Disable ad blockers or VPN',
          'Try a different network',
          'Check if Firebase services are blocked by your firewall'
        ];
      case 'auth/user-not-found':
        return [
          'Make sure you created an admin user in your Flutter app',
          'Check if the email address is correct',
          'Use the AdminSetupTool in your Flutter app to create an admin'
        ];
      case 'auth/wrong-password':
        return ['Check your password', 'Try resetting the password'];
      default:
        return ['Check Firebase console for more details'];
    }
  };

  const checkAdminUser = async () => {
    if (!email) {
      setResult({ error: 'Please enter an email address' });
      return;
    }

    setLoading(true);
    try {
      // Check if user exists in Firestore
      const usersQuery = query(
        collection(db, 'users'),
        where('email', '==', email)
      );
      const usersSnapshot = await getDocs(usersQuery);
      
      if (usersSnapshot.empty) {
        setResult({ 
          error: 'No user found with this email in Firestore',
          suggestion: 'Make sure you created an admin user using your Flutter app AdminSetupTool'
        });
      } else {
        const userData = usersSnapshot.docs[0].data();
        setResult({
          success: true,
          userData: {
            id: usersSnapshot.docs[0].id,
            name: userData.name,
            email: userData.email,
            role: userData.role,
            status: userData.status,
            isAdmin: userData.role === 'admin'
          }
        });
      }
    } catch (error: any) {
      setResult({ 
        error: 'Error checking Firestore: ' + error.message 
      });
    } finally {
      setLoading(false);
    }
  };

  const checkAllAdmins = async () => {
    setLoading(true);
    try {
      const adminsQuery = query(
        collection(db, 'users'),
        where('role', '==', 'admin')
      );
      const adminsSnapshot = await getDocs(adminsQuery);
      
      if (adminsSnapshot.empty) {
        setResult({ 
          error: 'No admin users found in the database',
          suggestion: 'You need to create an admin user first using your Flutter app AdminSetupTool'
        });
      } else {
        const admins = adminsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));
        setResult({
          success: true,
          allAdmins: admins
        });
      }
    } catch (error: any) {
      setResult({ 
        error: 'Error checking admins: ' + error.message 
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: '24px', maxWidth: '800px', margin: '0 auto' }}>
      <Card title="Firebase Authentication Debugger">
        <Space direction="vertical" style={{ width: '100%' }}>
          <Title level={4}>Debug Network & Firebase Issues</Title>
          
          {/* Connection Status */}
          {connectionStatus && (
            <Alert
              message={connectionStatus.message}
              description={`Last checked: ${connectionStatus.timestamp}`}
              type={connectionStatus.success ? 'success' : 'error'}
              showIcon
            />
          )}

          <div>
            <Text strong>Step 1: Test Network Connectivity</Text>
            <br />
            <Button 
              onClick={testNetworkConnectivity}
              loading={loading}
              style={{ marginTop: '8px' }}
            >
              Test Network Connection
            </Button>
            <Button 
              onClick={checkFirebaseConnection}
              style={{ marginTop: '8px', marginLeft: '8px' }}
            >
              Refresh Firebase Connection
            </Button>
          </div>

          <Divider />

          <div>
            <Text strong>Step 2: Test Firebase Authentication</Text>
            <Space style={{ marginTop: '8px' }}>
              <Input
                placeholder="Enter admin email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={{ width: '200px' }}
              />
              <Input.Password
                placeholder="Enter password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{ width: '200px' }}
              />
              <Button 
                type="primary" 
                onClick={testFirebaseAuth}
                loading={loading}
              >
                Test Login
              </Button>
            </Space>
          </div>

          <Divider />

          <div>
            <Text strong>Step 3: Check if admin user exists in Firestore</Text>
            <Space style={{ marginTop: '8px' }}>
              <Button 
                onClick={checkAdminUser}
                loading={loading}
              >
                Check User in Database
              </Button>
            </Space>
          </div>

          <div>
            <Text strong>Step 4: List all admin users</Text>
            <br />
            <Button 
              onClick={checkAllAdmins}
              loading={loading}
              style={{ marginTop: '8px' }}
            >
              List All Admins
            </Button>
          </div>

          <Divider />

          <div>
            <Text strong>Network & Firebase Connection Test</Text>
            <Button 
              onClick={testNetworkConnectivity}
              loading={loading}
              style={{ marginTop: '8px' }}
            >
              Test Network Connectivity
            </Button>
            <Button 
              onClick={checkFirebaseConnection}
              loading={loading}
              style={{ marginTop: '8px', marginLeft: '8px' }}
            >
              Test Firebase Connection
            </Button>
          </div>

          <div>
            <Text strong>Firebase Authentication Test</Text>
            <Space style={{ marginTop: '8px', display: 'flex', gap: '8px' }}>
              <Input
                placeholder="Enter admin email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={{ flex: 1 }}
              />
              <Input.Password
                placeholder="Enter password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{ flex: 1 }}
              />
              <Button 
                type="primary" 
                onClick={testFirebaseAuth}
                loading={loading}
                style={{ flex: 'none' }}
              >
                Test Auth
              </Button>
            </Space>
          </div>

          {result && (
            <div style={{ marginTop: '16px' }}>
              {result.error && (
                <Alert
                  message="Error"
                  description={
                    <div>
                      <p>{result.error}</p>
                      {result.suggestion && (
                        <p><strong>Suggestion:</strong> {result.suggestion}</p>
                      )}
                    </div>
                  }
                  type="error"
                  showIcon
                />
              )}
              
              {result.success && result.userData && (
                <Alert
                  message="User Found!"
                  description={
                    <div>
                      <p><strong>ID:</strong> {result.userData.id}</p>
                      <p><strong>Name:</strong> {result.userData.name}</p>
                      <p><strong>Email:</strong> {result.userData.email}</p>
                      <p><strong>Role:</strong> {result.userData.role}</p>
                      <p><strong>Status:</strong> {result.userData.status}</p>
                      <p><strong>Is Admin:</strong> {result.userData.isAdmin ? 'Yes' : 'No'}</p>
                    </div>
                  }
                  type={result.userData.isAdmin ? "success" : "warning"}
                  showIcon
                />
              )}

              {result.success && result.allAdmins && (
                <Alert
                  message={`Found ${result.allAdmins.length} Admin User(s)`}
                  description={
                    <div>
                      {result.allAdmins.map((admin: any, index: number) => (
                        <div key={index} style={{ marginBottom: '8px', padding: '8px', border: '1px solid #d9d9d9', borderRadius: '4px' }}>
                          <p><strong>Email:</strong> {admin.email}</p>
                          <p><strong>Name:</strong> {admin.name}</p>
                          <p><strong>Status:</strong> {admin.status}</p>
                        </div>
                      ))}
                    </div>
                  }
                  type="success"
                  showIcon
                />
              )}

              {connectionStatus && (
                <Alert
                  message="Firebase Connection Status"
                  description={
                    <div>
                      <p>{connectionStatus.message}</p>
                      <p><strong>Timestamp:</strong> {connectionStatus.timestamp}</p>
                      {connectionStatus.success && (
                        <p style={{ color: 'green' }}><strong>Connection Successful</strong></p>
                      )}
                      {!connectionStatus.success && (
                        <p style={{ color: 'red' }}><strong>Connection Failed: {connectionStatus.error}</strong></p>
                      )}
                    </div>
                  }
                  type={connectionStatus.success ? "success" : "error"}
                  showIcon
                />
              )}

              {result.details && (
                <Alert
                  message="Network Connectivity Test Result"
                  description={
                    <div>
                      <p><strong>Internet:</strong> {result.details.internet}</p>
                      <p><strong>Firebase:</strong> {result.details.firebase}</p>
                      <p><strong>Timestamp:</strong> {result.details.timestamp}</p>
                    </div>
                  }
                  type={result.success ? "success" : "error"}
                  showIcon
                />
              )}
            </div>
          )}

          <Alert
            message="Common Solutions"
            description={
              <div>
                <p><strong>1. No admin user found:</strong> Create an admin user using your Flutter app's AdminSetupTool</p>
                <p><strong>2. Wrong credentials:</strong> Double-check email and password</p>
                <p><strong>3. User exists but role is not 'admin':</strong> Update user role in Firestore</p>
                <p><strong>4. Firebase config mismatch:</strong> Ensure web config matches your Flutter app</p>
              </div>
            }
            type="info"
            showIcon
          />
        </Space>
      </Card>
    </div>
  );
};

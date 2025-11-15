import React, { useState, ReactNode } from 'react';
import { Layout, Menu, Button, Avatar, Dropdown, Typography, Space } from 'antd';
import { 
  DashboardOutlined,
  UserOutlined,
  ShopOutlined,
  TransactionOutlined,
  SettingOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  BellOutlined,
  TeamOutlined,
  FileTextOutlined,
  CommentOutlined
} from '@ant-design/icons';
import { BrowserRouter as Router, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { EnhancedDashboard } from './EnhancedDashboard';
import { UserManagement } from './UserManagement';
import { ProductManagement } from './ProductManagement';
import { TransactionMonitoring } from './TransactionMonitoring';
import { OrderMonitoring } from './OrderMonitoring';
import { AnnouncementManagement } from './AnnouncementManagement';
import { AdminSettings } from './AdminSettings';
import { LoginPage } from './LoginPage';
import { FirebaseDebugger } from './FirebaseDebugger';
import { CooperativeManagement } from './CooperativeManagement';

const { Header, Sider, Content } = Layout;
const { Title } = Typography;

const AdminLayout: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false);
  const { user, isAdmin, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = async () => {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  const menuItems = [
    {
      key: '/',
      icon: <DashboardOutlined />,
      label: 'System Overview',
    },
    {
      key: '/cooperative',
      icon: <TeamOutlined />,
      label: 'Cooperative Management',
    },
    {
      key: '/users',
      icon: <UserOutlined />,
      label: 'User Management',
    },
    {
      key: '/products',
      icon: <ShopOutlined />,
      label: 'Product Management',
    },
    {
      key: '/transactions',
      icon: <TransactionOutlined />,
      label: 'Order Management',
    },
    {
      key: '/announcements',
      icon: <BellOutlined />,
      label: 'Announcements',
    },
    {
      key: '/settings',
      icon: <SettingOutlined />,
      label: 'System Settings',
    },
  ];

  const userMenu = (
    <Menu>
      <Menu.Item key="profile" icon={<UserOutlined />}>
        Profile
      </Menu.Item>
      <Menu.Item key="settings" icon={<SettingOutlined />}>
        Settings
      </Menu.Item>
      <Menu.Divider />
      <Menu.Item key="logout" icon={<LogoutOutlined />} onClick={handleLogout}>
        Logout
      </Menu.Item>
    </Menu>
  );

  const handleMenuClick = (item: any) => {
    navigate(item.key);
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider 
        trigger={null} 
        collapsible 
        collapsed={collapsed}
        style={{
          overflow: 'auto',
          height: '100vh',
          position: 'fixed',
          left: 0,
          top: 0,
          bottom: 0,
          background: '#001529'
        }}
      >
        <div style={{ 
          height: '64px', 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center',
          borderBottom: '1px solid #303030'
        }}>
          <Title 
            level={4} 
            style={{ 
              color: 'white', 
              margin: 0,
              display: collapsed ? 'none' : 'block'
            }}
          >
            Admin Panel
          </Title>
        </div>
        
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={handleMenuClick}
          style={{ borderRight: 0 }}
        />
      </Sider>
      
      <Layout style={{ marginLeft: collapsed ? 80 : 200, transition: 'all 0.2s' }}>
        <Header style={{ 
          padding: '0 24px', 
          background: '#fff', 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'space-between',
          borderBottom: '1px solid #f0f0f0',
          position: 'sticky',
          top: 0,
          zIndex: 1
        }}>
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{ fontSize: '16px', width: 64, height: 64 }}
          />
          
          <Space>
            <span>Welcome, {user?.email}</span>
            <Dropdown overlay={userMenu} placement="bottomRight">
              <Avatar 
                style={{ backgroundColor: '#1890ff', cursor: 'pointer' }}
                icon={<UserOutlined />}
              />
            </Dropdown>
          </Space>
        </Header>
        
        <Content style={{ 
          margin: 0, 
          minHeight: 280, 
          background: '#f0f2f5'
        }}>
          <Routes>
            <Route path="/" element={<EnhancedDashboard />} />
            <Route path="/users" element={<UserManagement />} />
            <Route path="/cooperative" element={<CooperativeManagement />} />
            <Route path="/products" element={<ProductManagement />} />
            <Route path="/transactions" element={<OrderMonitoring />} />
            <Route path="/announcements" element={<AnnouncementManagement />} />
            <Route path="/settings" element={<AdminSettings />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Content>
      </Layout>
    </Layout>
  );
};

interface ProtectedRouteProps {
  children: ReactNode;
}

const ProtectedRoute = ({ children }: ProtectedRouteProps) => {
  const { user, isAdmin, loading } = useAuth();

  console.log('ProtectedRoute check:', { user: !!user, isAdmin, loading });

  if (loading) {
    return (
      <div style={{ 
        height: '100vh', 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center' 
      }}>
        <div>
          <div>Loading...</div>
          <div style={{ fontSize: '12px', marginTop: '8px', color: '#666' }}>
            Checking authentication status...
          </div>
        </div>
      </div>
    );
  }

  if (!user) {
    console.log('No user found, redirecting to login');
    return <Navigate to="/login" replace />;
  }

  if (!isAdmin) {
    console.log('User is not admin, redirecting to login');
    return <Navigate to="/login" replace />;
  }

  console.log('User is authenticated and admin, showing dashboard');
  return <>{children}</>;
};

export const App: React.FC = () => {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/debug" element={<FirebaseDebugger />} />
        <Route 
          path="/*" 
          element={
            <ProtectedRoute>
              <AdminLayout />
            </ProtectedRoute>
          } 
        />
      </Routes>
    </Router>
  );
};

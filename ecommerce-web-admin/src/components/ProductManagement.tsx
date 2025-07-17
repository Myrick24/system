import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Tag, Space, Tabs, message, Modal, Image } from 'antd';
import { 
  CheckOutlined, 
  CloseOutlined, 
  DeleteOutlined,
  ReloadOutlined,
  EyeOutlined
} from '@ant-design/icons';
import { ProductService } from '../services/productService';
import { Product } from '../types';

const { TabPane } = Tabs;

export const ProductManagement: React.FC = () => {
  const [allProducts, setAllProducts] = useState<Product[]>([]);
  const [pendingProducts, setPendingProducts] = useState<Product[]>([]);
  const [approvedProducts, setApprovedProducts] = useState<Product[]>([]);
  const [rejectedProducts, setRejectedProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('pending');
  const productService = new ProductService();

  useEffect(() => {
    loadProductData();
  }, []);

  const loadProductData = async () => {
    try {
      setLoading(true);
      const [all, pending, approved, rejected] = await Promise.all([
        productService.getAllProducts(),
        productService.getProductsByStatus('pending'),
        productService.getProductsByStatus('approved'),
        productService.getProductsByStatus('rejected')
      ]);

      setAllProducts(all);
      setPendingProducts(pending);
      setApprovedProducts(approved);
      setRejectedProducts(rejected);
    } catch (error) {
      console.error('Error loading product data:', error);
      message.error('Failed to load product data');
    } finally {
      setLoading(false);
    }
  };

  const handleApproveProduct = async (productId: string, productName: string) => {
    try {
      const success = await productService.approveProduct(productId);
      if (success) {
        message.success(`${productName} approved`);
        loadProductData();
      } else {
        message.error('Failed to approve product');
      }
    } catch (error) {
      console.error('Error approving product:', error);
      message.error('Failed to approve product');
    }
  };

  const handleRejectProduct = async (productId: string, productName: string) => {
    Modal.confirm({
      title: 'Reject Product',
      content: `Are you sure you want to reject "${productName}"?`,
      onOk: async () => {
        try {
          const success = await productService.rejectProduct(productId);
          if (success) {
            message.success(`${productName} rejected`);
            loadProductData();
          } else {
            message.error('Failed to reject product');
          }
        } catch (error) {
          console.error('Error rejecting product:', error);
          message.error('Failed to reject product');
        }
      }
    });
  };

  const handleDeleteProduct = async (productId: string, productName: string) => {
    Modal.confirm({
      title: 'Delete Product',
      content: `Are you sure you want to delete "${productName}"? This action cannot be undone.`,
      okType: 'danger',
      onOk: async () => {
        try {
          const success = await productService.deleteProduct(productId);
          if (success) {
            message.success(`${productName} deleted`);
            loadProductData();
          } else {
            message.error('Failed to delete product');
          }
        } catch (error) {
          console.error('Error deleting product:', error);
          message.error('Failed to delete product');
        }
      }
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved': return 'green';
      case 'pending': return 'orange';
      case 'rejected': return 'red';
      default: return 'default';
    }
  };

  const baseColumns = [
    {
      title: 'Image',
      dataIndex: 'images',
      key: 'image',
      width: 80,
      render: (images: string[]) => (
        images && images.length > 0 ? (
          <Image
            width={50}
            height={50}
            src={images[0]}
            fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMIAAADDCAYAAADQvc6UAAABRWlDQ1BJQ0MgUHJvZmlsZQAAKJFjYGASSSwoyGFhYGDIzSspCnJ3UoiIjFJgf8LAwSDCIMogwMCcmFxc4BgQ4ANUwgCjUcG3awyMIPqyLsis7PPOq3QdDFcvjV3jOD1boQVTPQrgSkktTgbSf4A4LbmgqISBgTEFyFYuLykAsTuAbJEioKOA7DkgdjqEvQHEToKwj4DVhAQ5A9k3gGyB5IxEoBmML4BsnSQk8XQkNtReEOBxcfXxUQg1Mjc0dyHgXNJBSWpFCYh2zi+oLMpMzyhRcASGUqqCZ16yno6CkYGRAQMDKMwhqj/fAIcloxgHQqxAjIHBEugw5sUIsSQpBobtQPdLciLEVJYzMPBHMDBsayhILEqEO4DxG0txmrERhM29nYGBddr//5/DGRjYNRkY/l7////39v///y4Dmn+LgeHANwDrkl1AuO+pmgAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAwqADAAQAAAABAAAAwwAAAAD9b/HnAAAHlklEQVR4Ae3dP3Ik1RnG4W+FgYxN"
            style={{ objectFit: 'cover', borderRadius: '4px' }}
          />
        ) : (
          <div style={{ width: 50, height: 50, backgroundColor: '#f0f0f0', borderRadius: '4px' }} />
        )
      )
    },
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
      sorter: (a: Product, b: Product) => a.name.localeCompare(b.name)
    },
    {
      title: 'Category',
      dataIndex: 'category',
      key: 'category',
      render: (category: string) => (
        <Tag color="blue">{category}</Tag>
      )
    },
    {
      title: 'Price',
      dataIndex: 'price',
      key: 'price',
      render: (price: number) => `$${price.toFixed(2)}`,
      sorter: (a: Product, b: Product) => a.price - b.price
    },
    {
      title: 'Inventory',
      dataIndex: 'inventory',
      key: 'inventory',
      sorter: (a: Product, b: Product) => a.inventory - b.inventory
    },
    {
      title: 'Seller',
      dataIndex: 'sellerName',
      key: 'sellerName'
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={getStatusColor(status)}>
          {status.toUpperCase()}
        </Tag>
      )
    }
  ];

  const pendingColumns = [
    ...baseColumns,
    {
      title: 'Actions',
      key: 'actions',
      render: (record: Product) => (
        <Space>
          <Button
            type="primary"
            icon={<CheckOutlined />}
            size="small"
            onClick={() => handleApproveProduct(record.id, record.name)}
          >
            Approve
          </Button>
          <Button
            danger
            icon={<CloseOutlined />}
            size="small"
            onClick={() => handleRejectProduct(record.id, record.name)}
          >
            Reject
          </Button>
        </Space>
      )
    }
  ];

  const managementColumns = [
    ...baseColumns,
    {
      title: 'Actions',
      key: 'actions',
      render: (record: Product) => (
        <Space>
          <Button
            danger
            icon={<DeleteOutlined />}
            size="small"
            onClick={() => handleDeleteProduct(record.id, record.name)}
          >
            Delete
          </Button>
        </Space>
      )
    }
  ];

  return (
    <div style={{ padding: '24px' }}>
      <Card
        title="Product Management"
        extra={
          <Button
            icon={<ReloadOutlined />}
            onClick={loadProductData}
            loading={loading}
          >
            Refresh
          </Button>
        }
      >
        <Tabs activeKey={activeTab} onChange={setActiveTab}>
          <TabPane tab={`Pending (${pendingProducts.length})`} key="pending">
            <Table
              dataSource={pendingProducts}
              columns={pendingColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`Approved (${approvedProducts.length})`} key="approved">
            <Table
              dataSource={approvedProducts}
              columns={managementColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`All Products (${allProducts.length})`} key="all">
            <Table
              dataSource={allProducts}
              columns={managementColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane tab={`Rejected (${rejectedProducts.length})`} key="rejected">
            <Table
              dataSource={rejectedProducts}
              columns={managementColumns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10 }}
              scroll={{ x: true }}
            />
          </TabPane>
        </Tabs>
      </Card>
    </div>
  );
};

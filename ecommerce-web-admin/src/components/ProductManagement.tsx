import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Tag, Space, Tabs, message, Modal, Image, Input } from 'antd';
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
const { TextArea } = Input;

export const ProductManagement: React.FC = () => {
  const [allProducts, setAllProducts] = useState<Product[]>([]);
  const [pendingProducts, setPendingProducts] = useState<Product[]>([]);
  const [approvedProducts, setApprovedProducts] = useState<Product[]>([]);
  const [rejectedProducts, setRejectedProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('pending');
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [detailModalVisible, setDetailModalVisible] = useState(false);
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
        message.success(`${productName} approved! Notifications sent to seller and buyers.`);
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
    let rejectionReason = '';
    
    Modal.confirm({
      title: 'Reject Product',
      content: (
        <div>
          <p>Are you sure you want to reject "{productName}"?</p>
          <p style={{ marginTop: '16px', marginBottom: '8px' }}>Please provide a reason (optional):</p>
          <TextArea
            rows={3}
            placeholder="e.g., Image quality is poor, description incomplete, pricing issue..."
            onChange={(e) => { rejectionReason = e.target.value; }}
          />
        </div>
      ),
      onOk: async () => {
        try {
          const success = await productService.rejectProduct(productId, rejectionReason.trim() || undefined);
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

  const handleRowClick = (record: Product) => {
    setSelectedProduct(record);
    setDetailModalVisible(true);
  };

  const handleCloseDetailModal = () => {
    setDetailModalVisible(false);
    setSelectedProduct(null);
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
      render: (_: any, record: Product) => {
        // Support both 'images' array and 'imageUrl' string
        const imageUrl = record.images?.[0] || record.imageUrl;
        return imageUrl ? (
          <Image
            width={50}
            height={50}
            src={imageUrl}
            fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMIAAADDCAYAAADQvc6UAAABRWlDQ1BJQ0MgUHJvZmlsZQAAKJFjYGASSSwoyGFhYGDIzSspCnJ3UoiIjFJgf8LAwSDCIMogwMCcmFxc4BgQ4ANUwgCjUcG3awyMIPqyLsis7PPOq3QdDFcvjV3jOD1boQVTPQrgSkktTgbSf4A4LbmgqISBgTEFyFYuLykAsTuAbJEioKOA7DkgdjqEvQHEToKwj4DVhAQ5A9k3gGyB5IxEoBmML4BsnSQk8XQkNtReEOBxcfXxUQg1Mjc0dyHgXNJBSWpFCYh2zi+oLMpMzyhRcASGUqqCZ16yno6CkYGRAQMDKMwhqj/fAIcloxgHQqxAjIHBEugw5sUIsSQpBobtQPdLciLEVJYzMPBHMDBsayhILEqEO4DxG0txmrERhM29nYGBddr//5/DGRjYNRkY/l7////39v///y4Dmn+LgeHANwDrkl1AuO+pmgAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAwqADAAQAAAABAAAAwwAAAAD9b/HnAAAHlklEQVR4Ae3dP3Ik1RnG4W+FgYxN"
            style={{ objectFit: 'cover', borderRadius: '4px' }}
          />
        ) : (
          <div style={{ width: 50, height: 50, backgroundColor: '#f0f0f0', borderRadius: '4px' }} />
        );
      }
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
      render: (price: number) => `₱${price.toFixed(2)}`,
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
              onRow={(record) => ({
                onClick: () => handleRowClick(record),
                style: { cursor: 'pointer' }
              })}
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
              onRow={(record) => ({
                onClick: () => handleRowClick(record),
                style: { cursor: 'pointer' }
              })}
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
              onRow={(record) => ({
                onClick: () => handleRowClick(record),
                style: { cursor: 'pointer' }
              })}
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
              onRow={(record) => ({
                onClick: () => handleRowClick(record),
                style: { cursor: 'pointer' }
              })}
            />
          </TabPane>
        </Tabs>
      </Card>

      {/* Product Details Modal */}
      <Modal
        title="Product Details"
        open={detailModalVisible}
        onCancel={handleCloseDetailModal}
        footer={[
          <Button key="close" onClick={handleCloseDetailModal}>
            Close
          </Button>,
          selectedProduct?.status === 'pending' && (
            <Button
              key="approve"
              type="primary"
              icon={<CheckOutlined />}
              onClick={() => {
                if (selectedProduct) {
                  handleApproveProduct(selectedProduct.id, selectedProduct.name);
                  handleCloseDetailModal();
                }
              }}
            >
              Approve
            </Button>
          ),
          selectedProduct?.status === 'pending' && (
            <Button
              key="reject"
              danger
              icon={<CloseOutlined />}
              onClick={() => {
                if (selectedProduct) {
                  handleRejectProduct(selectedProduct.id, selectedProduct.name);
                  handleCloseDetailModal();
                }
              }}
            >
              Reject
            </Button>
          ),
          selectedProduct && (
            <Button
              key="delete"
              danger
              icon={<DeleteOutlined />}
              onClick={() => {
                if (selectedProduct) {
                  handleDeleteProduct(selectedProduct.id, selectedProduct.name);
                  handleCloseDetailModal();
                }
              }}
            >
              Delete
            </Button>
          )
        ]}
        width={800}
      >
        {selectedProduct && (
          <div style={{ padding: '16px 0' }}>
            {/* Product Images */}
            <div style={{ marginBottom: '24px' }}>
              <h3 style={{ marginBottom: '12px', fontSize: '16px', fontWeight: 600 }}>Product Images</h3>
              {(() => {
                // Support both 'images' array and 'imageUrl' string
                const productImages = selectedProduct.images || 
                  (selectedProduct.imageUrl ? [selectedProduct.imageUrl] : []);
                
                return productImages.length > 0 ? (
                  <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                    <Image.PreviewGroup>
                      {productImages.map((image, index) => (
                        <Image
                          key={index}
                          width={150}
                          height={150}
                          src={image}
                          style={{ objectFit: 'cover', borderRadius: '8px' }}
                          fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMIAAADDCAYAAADQvc6UAAABRWlDQ1BJQ0MgUHJvZmlsZQAAKJFjYGASSSwoyGFhYGDIzSspCnJ3UoiIjFJgf8LAwSDCIMogwMCcmFxc4BgQ4ANUwgCjUcG3awyMIPqyLsis7PPOq3QdDFcvjV3jOD1boQVTPQrgSkktTgbSf4A4LbmgqISBgTEFyFYuLykAsTuAbJEioKOA7DkgdjqEvQHEToKwj4DVhAQ5A9k3gGyB5IxEoBmML4BsnSQk8XQkNtReEOBxcfXxUQg1Mjc0dyHgXNJBSWpFCYh2zi+oLMpMzyhRcASGUqqCZ16yno6CkYGRAQMDKMwhqj/fAIcloxgHQqxAjIHBEugw5sUIsSQpBobtQPdLciLEVJYzMPBHMDBsayhILEqEO4DxG0txmrERhM29nYGBddr//5/DGRjYNRkY/l7////39v///y4Dmn+LgeHANwDrkl1AuO+pmgAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAwqADAAQAAAABAAAAwwAAAAD9b/HnAAAHlklEQVR4Ae3dP3Ik1RnG4W+FgYxN"
                        />
                      ))}
                    </Image.PreviewGroup>
                  </div>
                ) : (
                  <div style={{ 
                    width: '100%', 
                    height: 150, 
                    backgroundColor: '#f0f0f0', 
                    borderRadius: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#999'
                  }}>
                    No images available
                  </div>
                );
              })()}
            </div>

            {/* Product Information */}
            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: '1fr 1fr', 
              gap: '16px',
              marginBottom: '24px' 
            }}>
              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Product Name</p>
                <p style={{ margin: 0, fontSize: '16px', fontWeight: 500 }}>{selectedProduct.name}</p>
              </div>
              
              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Category</p>
                <Tag color="blue" style={{ margin: 0 }}>{selectedProduct.category}</Tag>
              </div>

              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Price</p>
                <p style={{ margin: 0, fontSize: '20px', fontWeight: 600, color: '#52c41a' }}>
                  ₱{selectedProduct.price.toFixed(2)}
                </p>
              </div>

              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Inventory</p>
                <p style={{ margin: 0, fontSize: '16px', fontWeight: 500 }}>
                  {selectedProduct.inventory} units
                </p>
              </div>

              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Seller</p>
                <p style={{ margin: 0, fontSize: '16px', fontWeight: 500 }}>{selectedProduct.sellerName}</p>
              </div>

              <div>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Status</p>
                <Tag color={getStatusColor(selectedProduct.status)} style={{ margin: 0 }}>
                  {selectedProduct.status.toUpperCase()}
                </Tag>
              </div>

              <div style={{ gridColumn: '1 / -1' }}>
                <p style={{ margin: '8px 0', color: '#666', fontSize: '14px' }}>Created At</p>
                <p style={{ margin: 0, fontSize: '16px' }}>
                  {selectedProduct.createdAt?.toDate ? 
                    new Date(selectedProduct.createdAt.toDate()).toLocaleString() : 
                    'N/A'}
                </p>
              </div>
            </div>

            {/* Product Description */}
            <div>
              <h3 style={{ marginBottom: '12px', fontSize: '16px', fontWeight: 600 }}>Description</h3>
              <div style={{ 
                padding: '12px', 
                backgroundColor: '#f5f5f5', 
                borderRadius: '8px',
                fontSize: '14px',
                lineHeight: '1.6'
              }}>
                {selectedProduct.description || 'No description available'}
              </div>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

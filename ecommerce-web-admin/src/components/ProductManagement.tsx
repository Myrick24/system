import React, { useEffect, useState, useCallback } from 'react';
import { Card, Table, Button, Tag, Space, Tabs, message, Modal, Image, Input } from 'antd';
import { 
  CheckOutlined, 
  CloseOutlined, 
  DeleteOutlined,
  ReloadOutlined
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
  
  // Memoize productService to avoid creating new instances
  const productService = React.useMemo(() => new ProductService(), []);

  const loadProductData = useCallback(async () => {
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
  }, [productService]);

  useEffect(() => {
    loadProductData();
  }, [loadProductData]);

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
    console.log('Product record clicked:', record);
    console.log('Images in product:', record.images);
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
      dataIndex: 'currentStock',
      key: 'currentStock',
      render: (currentStock: number | undefined, record: Product) => {
        // Handle cases where currentStock is undefined or null
        const stockCount = currentStock ?? record.inventory ?? 0;
        console.log('Rendering inventory - Value:', stockCount, 'currentStock:', currentStock, 'inventory:', record.inventory);
        
        let color = 'green';
        let status = 'In Stock';
        
        if (stockCount <= 0) {
          color = 'red';
          status = 'Out of Stock';
        } else if (stockCount < 5) {
          color = 'orange';
          status = 'Low Stock';
        } else if (stockCount >= 100) {
          color = 'blue';
          status = 'Well Stocked';
        }
        
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Tag color={color}>{status}</Tag>
            <span style={{ fontSize: '12px', color: '#666' }}>({stockCount} units)</span>
          </div>
        );
      },
      sorter: (a: Product, b: Product) => (a.currentStock ?? a.inventory ?? 0) - (b.currentStock ?? b.inventory ?? 0)
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
        <Space onClick={(e) => e.stopPropagation()}>
          <Button
            type="primary"
            icon={<CheckOutlined />}
            size="small"
            onClick={(e) => {
              e.stopPropagation();
              handleApproveProduct(record.id, record.name);
            }}
          >
            Approve
          </Button>
          <Button
            danger
            icon={<CloseOutlined />}
            size="small"
            onClick={(e) => {
              e.stopPropagation();
              handleRejectProduct(record.id, record.name);
            }}
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
        <Space onClick={(e) => e.stopPropagation()}>
          <Button
            danger
            icon={<DeleteOutlined />}
            size="small"
            onClick={(e) => {
              e.stopPropagation();
              handleDeleteProduct(record.id, record.name);
            }}
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

      {/* Product Details Modal - Modern Redesign */}
      <Modal
        title={null}
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
        width={1100}
        bodyStyle={{ padding: '32px' }}
      >
        {selectedProduct && (
          <div style={{ padding: '0' }}>
            {/* Hero Section with Title and Status */}
            <div style={{
              marginBottom: '32px',
              paddingBottom: '24px',
              borderBottom: '2px solid #f0f0f0',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'flex-start'
            }}>
              <div>
                <h1 style={{ 
                  margin: '0 0 8px 0',
                  fontSize: '28px', 
                  fontWeight: 700, 
                  color: '#1f1f1f',
                  lineHeight: '1.2'
                }}>
                  {selectedProduct.name}
                </h1>
                <p style={{ 
                  margin: 0,
                  fontSize: '13px',
                  color: '#8c8c8c',
                  textTransform: 'uppercase',
                  letterSpacing: '0.5px'
                }}>
                  Product ID: {selectedProduct.id}
                </p>
              </div>
              <Tag 
                color={getStatusColor(selectedProduct.status)} 
                style={{ 
                  fontSize: '12px', 
                  padding: '8px 16px', 
                  margin: 0,
                  fontWeight: 600,
                  textTransform: 'uppercase'
                }}
              >
                {selectedProduct.status}
              </Tag>
            </div>

            {/* Main Content Grid - 3 Columns */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '24px', marginBottom: '32px' }}>
              
              {/* Gallery Card */}
              <div style={{
                gridColumn: '1 / 2',
                backgroundColor: '#fafafa',
                borderRadius: '12px',
                padding: '24px',
                border: '1px solid #e8e8e8',
                display: 'flex',
                flexDirection: 'column'
              }}>
                <h3 style={{ 
                  margin: '0 0 16px 0', 
                  fontSize: '12px', 
                  fontWeight: 700, 
                  color: '#595959',
                  textTransform: 'uppercase',
                  letterSpacing: '0.5px'
                }}>
                  📸 Gallery
                </h3>
                {(() => {
                  let productImages: string[] = [];
                  
                  if (Array.isArray(selectedProduct.images) && selectedProduct.images.length > 0) {
                    productImages = selectedProduct.images;
                  } else if (Array.isArray(selectedProduct.imageUrls) && selectedProduct.imageUrls.length > 0) {
                    productImages = selectedProduct.imageUrls;
                  } else if (selectedProduct.imageUrl) {
                    productImages = [selectedProduct.imageUrl];
                  }
                  
                  return productImages.length > 0 ? (
                    <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', flex: 1, alignContent: 'flex-start' }}>
                      <Image.PreviewGroup>
                        {productImages.map((image, index) => (
                          <Image
                            key={index}
                            width={100}
                            height={100}
                            src={image}
                            style={{ 
                              objectFit: 'cover', 
                              borderRadius: '8px', 
                              cursor: 'pointer', 
                              border: '2px solid #d9d9d9',
                              transition: 'all 0.3s ease'
                            }}
                            fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMIAAADDCAYAAADQvc6UAAABRWlDQ1BJQ0MgUHJvZmlsZQAAKJFjYGASSSwoyGFhYGDIzSspCnJ3UoiIjFJgf8LAwSDCIMogwMCcmFxc4BgQ4ANUwgCjUcG3awyMIPqyLsis7PPOq3QdDFcvjV3jOD1boQVTPQrgSkktTgbSf4A4LbmgqISBgTEFyFYuLykAsTuAbJEioKOA7DkgdjqEvQHEToKwj4DVhAQ5A9k3gGyB5IxEoBmML4BsnSQk8XQkNtReEOBxcfXxUQg1Mjc0dyHgXNJBSWpFCYh2zi+oLMpMzyhRcASGUqqCZ16yno6CkYGRAQMDKMwhqj/fAIcloxgHQqxAjIHBEugw5sUIsSQpBobtQPdLciLEVJYzMPBHMDBsayhILEqEO4DxG0txmrERhM29nYGBddr//5/DGRjYNRkY/l7////39v///y4Dmn+LgeHANwDrkl1AuO+pmgAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAwqADAAQAAAABAAAAwwAAAAD9b/HnAAAHlklEQVR4Ae3dP3Ik1RnG4W+FgYxN"
                          />
                        ))}
                      </Image.PreviewGroup>
                    </div>
                  ) : (
                    <div style={{ 
                      width: '100%', 
                      height: 150, 
                      backgroundColor: '#fff',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#999',
                      border: '2px dashed #e8e8e8',
                      fontSize: '12px'
                    }}>
                      No images
                    </div>
                  );
                })()}
              </div>

              {/* Pricing & Stock Card */}
              <div style={{
                gridColumn: '2 / 3',
                display: 'flex',
                flexDirection: 'column',
                gap: '16px'
              }}>
                {/* Price Card */}
                <div style={{
                  backgroundColor: '#f6ffed',
                  borderRadius: '12px',
                  padding: '20px',
                  border: '2px solid #b7eb8f'
                }}>
                  <p style={{ 
                    margin: '0 0 8px 0', 
                    fontSize: '11px', 
                    fontWeight: 700, 
                    color: '#595959', 
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    💰 Price
                  </p>
                  <p style={{ 
                    margin: 0, 
                    fontSize: '32px', 
                    fontWeight: 800, 
                    color: '#52c41a',
                    lineHeight: '1'
                  }}>
                    ₱{selectedProduct.price.toFixed(2)}
                  </p>
                </div>

                {/* Stock Card */}
                <div style={{
                  backgroundColor: '#e6f7ff',
                  borderRadius: '12px',
                  padding: '20px',
                  border: '2px solid #91d5ff'
                }}>
                  <p style={{ 
                    margin: '0 0 12px 0', 
                    fontSize: '11px', 
                    fontWeight: 700, 
                    color: '#595959',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    📦 Inventory Status
                  </p>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {(() => {
                      const stockCount = selectedProduct?.currentStock ?? selectedProduct?.inventory ?? 0;
                      let color = 'green';
                      let status = 'In Stock';
                      let bgColor = '#f6ffed';
                      let borderColor = '#b7eb8f';
                      
                      if (stockCount <= 0) {
                        color = 'red';
                        status = 'Out of Stock';
                        bgColor = '#fff1f0';
                        borderColor = '#ffccc7';
                      } else if (stockCount < 5) {
                        color = 'orange';
                        status = 'Low Stock';
                        bgColor = '#fffbe6';
                        borderColor = '#ffe58f';
                      } else if (stockCount >= 100) {
                        color = 'blue';
                        status = 'Well Stocked';
                        bgColor = '#e6f7ff';
                        borderColor = '#91d5ff';
                      }
                      
                      return (
                        <>
                          <Tag color={color} style={{ margin: 0, fontSize: '11px', fontWeight: 600 }}>
                            {status}
                          </Tag>
                          <p style={{ 
                            margin: 0, 
                            fontSize: '20px', 
                            fontWeight: 700, 
                            color: '#1f1f1f'
                          }}>
                            {stockCount}
                          </p>
                          <p style={{ 
                            margin: 0, 
                            fontSize: '12px', 
                            color: '#8c8c8c'
                          }}>
                            units available
                          </p>
                        </>
                      );
                    })()}
                  </div>
                </div>
              </div>

              {/* Seller Info & Category Card */}
              <div style={{
                gridColumn: '3 / 4',
                backgroundColor: '#f5f5f5',
                borderRadius: '12px',
                padding: '20px',
                border: '1px solid #e8e8e8',
                display: 'flex',
                flexDirection: 'column',
                gap: '16px'
              }}>
                <div>
                  <p style={{ 
                    margin: '0 0 8px 0', 
                    fontSize: '11px', 
                    fontWeight: 700, 
                    color: '#8c8c8c',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    👤 Seller
                  </p>
                  <p style={{ 
                    margin: 0, 
                    fontSize: '16px', 
                    fontWeight: 600, 
                    color: '#1f1f1f'
                  }}>
                    {selectedProduct.sellerName}
                  </p>
                </div>

                <div style={{ borderTop: '1px solid #e8e8e8', paddingTop: '16px' }}>
                  <p style={{ 
                    margin: '0 0 8px 0', 
                    fontSize: '11px', 
                    fontWeight: 700, 
                    color: '#8c8c8c',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    🏷️ Category
                  </p>
                  <Tag color="blue" style={{ margin: 0, fontSize: '12px', fontWeight: 600 }}>
                    {selectedProduct.category}
                  </Tag>
                </div>

                <div style={{ borderTop: '1px solid #e8e8e8', paddingTop: '16px' }}>
                  <p style={{ 
                    margin: '0 0 8px 0', 
                    fontSize: '11px', 
                    fontWeight: 700, 
                    color: '#8c8c8c',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px'
                  }}>
                    📅 Created
                  </p>
                  <p style={{ 
                    margin: 0, 
                    fontSize: '12px', 
                    color: '#1f1f1f'
                  }}>
                    {selectedProduct.createdAt?.toDate ? 
                      new Date(selectedProduct.createdAt.toDate()).toLocaleDateString('en-US', { 
                        year: 'numeric', 
                        month: 'short', 
                        day: 'numeric'
                      }) : 
                      'N/A'}
                  </p>
                </div>
              </div>
            </div>

            {/* Description Section - Full Width */}
            <div style={{
              backgroundColor: '#fafafa',
              borderRadius: '12px',
              padding: '24px',
              border: '1px solid #e8e8e8'
            }}>
              <h3 style={{ 
                margin: '0 0 16px 0', 
                fontSize: '12px', 
                fontWeight: 700, 
                color: '#595959',
                textTransform: 'uppercase',
                letterSpacing: '0.5px'
              }}>
                📝 Product Description
              </h3>
              <p style={{ 
                margin: 0, 
                fontSize: '14px', 
                lineHeight: '1.8',
                color: '#1f1f1f',
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-word'
              }}>
                {selectedProduct.description || 'No description available'}
              </p>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

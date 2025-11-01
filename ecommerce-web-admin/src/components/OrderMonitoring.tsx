import React, { useEffect, useState } from 'react';
import { 
  Card, Table, Button, Tag, Space, Tabs, message, DatePicker, Select, Modal, Input, Drawer,
  Statistic, Row, Col, Divider, Timeline, Badge, Image as AntImage
} from 'antd';
import { 
  ReloadOutlined, EyeOutlined, EditOutlined, DeleteOutlined, 
  CheckCircleOutlined, ClockCircleOutlined, ShoppingCartOutlined,
  DollarOutlined, UserOutlined, TruckOutlined, CheckOutlined
} from '@ant-design/icons';
import { OrderService, Order } from '../services/orderService';
import dayjs from 'dayjs';

const { TabPane } = Tabs;
const { RangePicker } = DatePicker;

export const OrderMonitoring: React.FC = () => {
  const [allOrders, setAllOrders] = useState<Order[]>([]);
  const [filteredOrders, setFilteredOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('all');
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [detailDrawerVisible, setDetailDrawerVisible] = useState(false);
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);
  const [searchText, setSearchText] = useState('');
  const orderService = new OrderService();

  const orderStatuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'rejected'];

  useEffect(() => {
    loadOrders();
  }, []);

  const loadOrders = async () => {
    try {
      setLoading(true);
      const orders = await orderService.getAllOrders();
      setAllOrders(orders);
      filterOrders(orders, activeTab);
    } catch (error) {
      console.error('Error loading orders:', error);
      message.error('Failed to load orders');
    } finally {
      setLoading(false);
    }
  };

  const filterOrders = (orders: Order[], status: string) => {
    let filtered = orders;

    if (status !== 'all') {
      filtered = filtered.filter(order => order.status === status);
    }

    if (searchText) {
      const searchLower = searchText.toLowerCase();
      filtered = filtered.filter(order =>
        order.productName.toLowerCase().includes(searchLower) ||
        order.buyerName?.toLowerCase().includes(searchLower) ||
        order.sellerName?.toLowerCase().includes(searchLower) ||
        order.id.toLowerCase().includes(searchLower)
      );
    }

    if (dateRange) {
      const [startDate, endDate] = dateRange;
      filtered = filtered.filter(order => {
        const orderDate = order.timestamp?.toDate ? order.timestamp.toDate() : new Date(order.timestamp);
        return orderDate >= startDate.toDate() && orderDate <= endDate.toDate();
      });
    }

    setFilteredOrders(filtered);
  };

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    filterOrders(allOrders, tab);
  };

  const handleStatusUpdate = async (order: Order, newStatus: string) => {
    try {
      await orderService.updateOrderStatus(order.id, newStatus);
      message.success(`Order status updated to ${newStatus}`);
      loadOrders();
    } catch (error) {
      console.error('Error updating status:', error);
      message.error('Failed to update order status');
    }
  };

  const showOrderDetails = (order: Order) => {
    setSelectedOrder(order);
    setDetailDrawerVisible(true);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'delivered':
        return 'green';
      case 'shipped':
        return 'blue';
      case 'processing':
        return 'orange';
      case 'pending':
        return 'orange';
      case 'cancelled':
        return 'red';
      case 'rejected':
        return 'red';
      default:
        return 'default';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'delivered':
        return <CheckCircleOutlined />;
      case 'shipped':
        return <TruckOutlined />;
      case 'processing':
        return <ClockCircleOutlined />;
      case 'pending':
        return <ShoppingCartOutlined />;
      default:
        return <ClockCircleOutlined />;
    }
  };

  const columns = [
    {
      title: 'Order ID',
      dataIndex: 'id',
      key: 'id',
      width: 100,
      render: (id: string) => (
        <span style={{ fontFamily: 'monospace', fontSize: '11px' }}>
          {id.substring(0, 10)}
        </span>
      ),
    },
    {
      title: 'Product',
      dataIndex: 'productName',
      key: 'productName',
      width: 150,
    },
    {
      title: 'Quantity',
      dataIndex: 'quantity',
      key: 'quantity',
      width: 100,
      render: (quantity: number, record: Order) => (
        <span style={{ fontWeight: 600, color: '#1890ff' }}>
          {record.quantityLabel || `${quantity} units`}
        </span>
      ),
    },
    {
      title: 'Buyer',
      dataIndex: 'buyerName',
      key: 'buyerName',
      width: 120,
    },
    {
      title: 'Seller',
      dataIndex: 'sellerName',
      key: 'sellerName',
      width: 120,
    },
    {
      title: 'Coop Name',
      dataIndex: 'coopName',
      key: 'coopName',
      width: 140,
      render: (coopName: string) => (
        coopName ? (
          <Tag color="green" style={{ marginRight: 0 }}>
            {coopName}
          </Tag>
        ) : (
          <span style={{ color: '#999' }}>N/A</span>
        )
      ),
    },
    {
      title: 'Amount',
      dataIndex: 'totalAmount',
      key: 'totalAmount',
      width: 100,
      render: (amount: number) => (
        <span style={{ fontWeight: 700, color: '#52c41a', fontSize: '14px' }}>
          ₱{amount.toFixed(2)}
        </span>
      ),
      sorter: (a: Order, b: Order) => a.totalAmount - b.totalAmount,
    },
    {
      title: 'Order Date',
      dataIndex: 'timestamp',
      key: 'timestamp',
      width: 150,
      render: (timestamp: any) => {
        if (!timestamp) return 'N/A';
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return dayjs(date).format('MMM DD, YYYY hh:mm A');
      },
      sorter: (a: Order, b: Order) => {
        const dateA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp);
        const dateB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp);
        return dateA.getTime() - dateB.getTime();
      },
    },
    {
      title: 'Delivery',
      dataIndex: 'deliveryMethod',
      key: 'deliveryMethod',
      width: 120,
      render: (method: string) => (
        <Tag color="blue" icon={<TruckOutlined />}>
          {method || 'Standard'}
        </Tag>
      ),
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      width: 110,
      render: (status: string, record: Order) => (
        <Tag
          color={getStatusColor(status)}
          icon={getStatusIcon(status)}
          style={{ marginRight: 0 }}
        >
          <span style={{ textTransform: 'capitalize' }}>
            {status}
          </span>
        </Tag>
      ),
    },
  ];

  const getNextStatus = (currentStatus: string): string => {
    const statusFlow: { [key: string]: string } = {
      pending: 'processing',
      processing: 'shipped',
      shipped: 'delivered',
      delivered: 'completed',
    };
    return statusFlow[currentStatus] || currentStatus;
  };

  const calculateStats = (orders: Order[]) => {
    return {
      total: orders.length,
      totalRevenue: orders.reduce((sum, order) => sum + order.totalAmount, 0),
      pending: orders.filter(o => o.status === 'pending').length,
      processing: orders.filter(o => o.status === 'processing').length,
      shipped: orders.filter(o => o.status === 'shipped').length,
      delivered: orders.filter(o => o.status === 'delivered').length,
      cancelled: orders.filter(o => o.status === 'cancelled').length,
    };
  };

  const stats = calculateStats(filteredOrders);

  return (
    <div style={{ padding: '24px' }}>
      {/* Statistics Cards */}
      <Row gutter={[16, 16]} style={{ marginBottom: '24px' }}>
        <Col xs={24} sm={12} md={6}>
          <Card>
            <Statistic
              title="Total Orders"
              value={stats.total}
              prefix={<ShoppingCartOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} md={6}>
          <Card>
            <Statistic
              title="Total Revenue"
              value={stats.totalRevenue}
              prefix="₱"
              valueStyle={{ color: '#52c41a' }}
              precision={2}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} md={6}>
          <Card>
            <Statistic
              title="Pending"
              value={stats.pending}
              valueStyle={{ color: '#faad14' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} md={6}>
          <Card>
            <Statistic
              title="Delivered"
              value={stats.delivered}
              valueStyle={{ color: '#52c41a' }}
            />
          </Card>
        </Col>
      </Row>

      {/* Main Orders Card */}
      <Card
        title="Order Management"
        extra={
          <Space>
            <Input.Search
              placeholder="Search orders..."
              allowClear
              style={{ width: 200 }}
              onSearch={setSearchText}
              onChange={(e) => {
                setSearchText(e.target.value);
                filterOrders(allOrders, activeTab);
              }}
            />
            <RangePicker
              value={dateRange}
              onChange={(dates: any) => {
                setDateRange(dates);
                filterOrders(allOrders, activeTab);
              }}
              placeholder={['Start', 'End']}
            />
            <Button onClick={() => {
              setDateRange(null);
              setSearchText('');
              loadOrders();
            }}>
              Reset
            </Button>
            <Button
              icon={<ReloadOutlined />}
              onClick={loadOrders}
              loading={loading}
            >
              Refresh
            </Button>
          </Space>
        }
      >
        <Tabs activeKey={activeTab} onChange={handleTabChange}>
          <TabPane
            tab={
              <span>
                All Orders ({allOrders.length})
                <br />
                <small style={{ color: '#1890ff' }}>
                  ₱{calculateStats(allOrders).totalRevenue.toFixed(2)}
                </small>
              </span>
            }
            key="all"
          >
            <Table
              dataSource={filteredOrders}
              columns={columns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 15, showSizeChanger: true, showTotal: (total) => `Total: ${total} orders` }}
              scroll={{ x: 1400 }}
              size="middle"
            />
          </TabPane>

          {orderStatuses.map(status => (
            <TabPane
              key={status}
              tab={
                <span>
                  {status.charAt(0).toUpperCase() + status.slice(1)} (
                  {allOrders.filter(o => o.status === status).length})
                  <br />
                  <small style={{ color: getStatusColor(status) }}>
                    ₱{calculateStats(allOrders.filter(o => o.status === status)).totalRevenue.toFixed(2)}
                  </small>
                </span>
              }
            >
              <Table
                dataSource={filteredOrders}
                columns={columns}
                rowKey="id"
                loading={loading}
                pagination={{ pageSize: 15, showSizeChanger: true, showTotal: (total) => `Total: ${total} orders` }}
                scroll={{ x: 1400 }}
                size="middle"
              />
            </TabPane>
          ))}
        </Tabs>
      </Card>

      {/* Order Details Drawer */}
      <Drawer
        title={`Order Details: ${selectedOrder?.id.substring(0, 16)}...`}
        placement="right"
        onClose={() => setDetailDrawerVisible(false)}
        open={detailDrawerVisible}
        width={500}
      >
        {selectedOrder && (
          <div>
            {/* Order Header */}
            <div style={{ marginBottom: '24px' }}>
              <h3 style={{ marginBottom: '12px', fontWeight: 700, fontSize: '16px' }}>
                {selectedOrder.productName}
              </h3>
              <Badge
                color={getStatusColor(selectedOrder.status)}
                text={
                  <span style={{ fontSize: '14px', fontWeight: 600, textTransform: 'capitalize' }}>
                    Status: {selectedOrder.status}
                  </span>
                }
              />
            </div>

            <Divider />

            {/* Product Image */}
            {selectedOrder.productImage && (
              <div style={{ marginBottom: '24px', textAlign: 'center' }}>
                <AntImage
                  src={selectedOrder.productImage}
                  style={{ maxWidth: '100%', maxHeight: '200px', borderRadius: '8px' }}
                  preview
                />
              </div>
            )}

            {/* Order Info */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ marginBottom: '12px', fontWeight: 600 }}>Order Information</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', fontSize: '14px' }}>
                <div>
                  <strong>Order ID:</strong>
                  <div style={{ fontFamily: 'monospace', color: '#8c8c8c', fontSize: '11px' }}>
                    {selectedOrder.id}
                  </div>
                </div>
                <div>
                  <strong>Date:</strong>
                  <div style={{ color: '#8c8c8c' }}>
                    {selectedOrder.timestamp?.toDate
                      ? dayjs(selectedOrder.timestamp.toDate()).format('MMM DD, YYYY')
                      : 'N/A'}
                  </div>
                </div>
                <div>
                  <strong>Quantity:</strong>
                  <div style={{ color: '#8c8c8c' }}>{selectedOrder.quantity}</div>
                </div>
                <div>
                  <strong>Unit Price:</strong>
                  <div style={{ color: '#8c8c8c' }}>₱{selectedOrder.price?.toFixed(2) || 'N/A'}</div>
                </div>
              </div>
            </div>

            <Divider />

            {/* Buyer Info */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ marginBottom: '12px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <UserOutlined /> Buyer Information
              </h4>
              <div style={{ fontSize: '14px' }}>
                <div style={{ marginBottom: '8px' }}>
                  <strong>Name:</strong> {selectedOrder.buyerName}
                </div>
                <div style={{ marginBottom: '8px' }}>
                  <strong>Email:</strong> {selectedOrder.buyerEmail}
                </div>
              </div>
            </div>

            <Divider />

            {/* Seller Info */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ marginBottom: '12px', fontWeight: 600 }}>Seller Information</h4>
              <div style={{ fontSize: '14px' }}>
                <strong>Name:</strong> {selectedOrder.sellerName}
              </div>
            </div>

            <Divider />

            {/* Delivery Info */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ marginBottom: '12px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <TruckOutlined /> Delivery Information
              </h4>
              <div style={{ fontSize: '14px' }}>
                <div style={{ marginBottom: '8px' }}>
                  <strong>Method:</strong> {selectedOrder.deliveryMethod || 'Standard'}
                </div>
                {selectedOrder.deliveryAddress && (
                  <div style={{ marginBottom: '8px' }}>
                    <strong>Address:</strong> {selectedOrder.deliveryAddress}
                  </div>
                )}
                {selectedOrder.meetupLocation && (
                  <div style={{ marginBottom: '8px' }}>
                    <strong>Meetup Location:</strong> {selectedOrder.meetupLocation}
                  </div>
                )}
              </div>
            </div>

            <Divider />

            {/* Amount */}
            <div style={{ marginBottom: '24px', backgroundColor: '#f0f5ff', padding: '16px', borderRadius: '8px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '16px' }}>
                <strong>Total Amount:</strong>
                <span style={{ fontSize: '20px', fontWeight: 700, color: '#52c41a' }}>
                  ₱{selectedOrder.totalAmount.toFixed(2)}
                </span>
              </div>
            </div>

            {/* Notes */}
            {selectedOrder.notes && (
              <>
                <Divider />
                <div>
                  <h4 style={{ marginBottom: '12px', fontWeight: 600 }}>Notes</h4>
                  <div style={{ backgroundColor: '#fafafa', padding: '12px', borderRadius: '6px', fontSize: '14px' }}>
                    {selectedOrder.notes}
                  </div>
                </div>
              </>
            )}

            {/* Status Update Buttons */}
            <Divider />
            <div style={{ marginTop: '24px' }}>
              <h4 style={{ marginBottom: '12px', fontWeight: 600 }}>Update Status</h4>
              <Space direction="vertical" style={{ width: '100%' }}>
                {orderStatuses.map(status => (
                  <Button
                    key={status}
                    block
                    size="large"
                    onClick={() => {
                      Modal.confirm({
                        title: 'Confirm Status Update',
                        content: `Update order status to "${status}"?`,
                        okText: 'Yes',
                        cancelText: 'No',
                        onOk() {
                          handleStatusUpdate(selectedOrder, status);
                          setDetailDrawerVisible(false);
                        },
                      });
                    }}
                    type={selectedOrder.status === status ? 'primary' : 'default'}
                    style={{
                      borderColor: getStatusColor(status),
                      color: selectedOrder.status === status ? '#fff' : getStatusColor(status),
                      backgroundColor: selectedOrder.status === status ? getStatusColor(status) : 'transparent',
                    }}
                  >
                    {status.charAt(0).toUpperCase() + status.slice(1)}
                  </Button>
                ))}
              </Space>
            </div>
          </div>
        )}
      </Drawer>
    </div>
  );
};

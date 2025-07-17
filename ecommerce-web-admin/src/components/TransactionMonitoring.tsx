import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Tag, Space, Tabs, message, DatePicker, Select } from 'antd';
import { ReloadOutlined, DollarOutlined } from '@ant-design/icons';
import { TransactionService } from '../services/transactionService';
import { Transaction } from '../types';
import dayjs from 'dayjs';

const { TabPane } = Tabs;
const { RangePicker } = DatePicker;
const { Option } = Select;

export const TransactionMonitoring: React.FC = () => {
  const [allTransactions, setAllTransactions] = useState<Transaction[]>([]);
  const [pendingTransactions, setPendingTransactions] = useState<Transaction[]>([]);
  const [completedTransactions, setCompletedTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('all');
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);
  const transactionService = new TransactionService();

  useEffect(() => {
    loadTransactionData();
  }, []);

  const loadTransactionData = async () => {
    try {
      setLoading(true);
      
      let transactions;
      if (dateRange) {
        const [startDate, endDate] = dateRange;
        transactions = await transactionService.getTransactionsByDateRange(
          startDate.toDate(),
          endDate.toDate()
        );
      } else {
        transactions = await transactionService.getAllTransactions();
      }

      const pending = transactions.filter(t => t.status === 'pending');
      const completed = transactions.filter(t => t.status === 'completed');

      setAllTransactions(transactions);
      setPendingTransactions(pending);
      setCompletedTransactions(completed);
    } catch (error) {
      console.error('Error loading transaction data:', error);
      message.error('Failed to load transaction data');
    } finally {
      setLoading(false);
    }
  };

  const handleStatusUpdate = async (transactionId: string, newStatus: string) => {
    try {
      const success = await transactionService.updateTransactionStatus(transactionId, newStatus);
      if (success) {
        message.success(`Transaction status updated to ${newStatus}`);
        loadTransactionData();
      } else {
        message.error('Failed to update transaction status');
      }
    } catch (error) {
      console.error('Error updating transaction status:', error);
      message.error('Failed to update transaction status');
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'green';
      case 'pending': return 'orange';
      case 'canceled': return 'red';
      case 'refunded': return 'purple';
      default: return 'default';
    }
  };

  const handleDateRangeChange = (dates: any) => {
    setDateRange(dates);
  };

  const resetFilters = () => {
    setDateRange(null);
    loadTransactionData();
  };

  const columns = [
    {
      title: 'Transaction ID',
      dataIndex: 'id',
      key: 'id',
      width: 150,
      render: (id: string) => id.substring(0, 8) + '...'
    },
    {
      title: 'Product',
      dataIndex: 'productName',
      key: 'productName'
    },
    {
      title: 'Quantity',
      dataIndex: 'quantity',
      key: 'quantity'
    },
    {
      title: 'Amount',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount: number) => (
        <span style={{ fontWeight: 'bold', color: '#52c41a' }}>
          ${amount.toFixed(2)}
        </span>
      ),
      sorter: (a: Transaction, b: Transaction) => a.amount - b.amount
    },
    {
      title: 'Payment Method',
      dataIndex: 'paymentMethod',
      key: 'paymentMethod',
      render: (method: string) => (
        <Tag color="blue">{method}</Tag>
      )
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
    },
    {
      title: 'Date',
      dataIndex: 'timestamp',
      key: 'timestamp',
      render: (timestamp: any) => {
        if (!timestamp) return 'N/A';
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return dayjs(date).format('MMM DD, YYYY HH:mm');
      },
      sorter: (a: Transaction, b: Transaction) => {
        const dateA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp);
        const dateB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp);
        return dateA.getTime() - dateB.getTime();
      }
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (record: Transaction) => (
        <Space>
          {record.status === 'pending' && (
            <>
              <Button
                type="primary"
                size="small"
                onClick={() => handleStatusUpdate(record.id, 'completed')}
              >
                Complete
              </Button>
              <Button
                danger
                size="small"
                onClick={() => handleStatusUpdate(record.id, 'canceled')}
              >
                Cancel
              </Button>
            </>
          )}
          {record.status === 'completed' && (
            <Button
              type="default"
              size="small"
              onClick={() => handleStatusUpdate(record.id, 'refunded')}
            >
              Refund
            </Button>
          )}
        </Space>
      )
    }
  ];

  const calculateTotal = (transactions: Transaction[]) => {
    return transactions.reduce((sum, transaction) => sum + transaction.amount, 0);
  };

  return (
    <div style={{ padding: '24px' }}>
      <Card
        title="Transaction Monitoring"
        extra={
          <Space>
            <RangePicker
              value={dateRange}
              onChange={handleDateRangeChange}
              placeholder={['Start Date', 'End Date']}
            />
            <Button onClick={resetFilters}>Reset</Button>
            <Button
              icon={<ReloadOutlined />}
              onClick={loadTransactionData}
              loading={loading}
            >
              Refresh
            </Button>
          </Space>
        }
      >
        <Tabs activeKey={activeTab} onChange={setActiveTab}>
          <TabPane 
            tab={
              <span>
                All Transactions ({allTransactions.length})
                <br />
                <small style={{ color: '#52c41a' }}>
                  Total: ${calculateTotal(allTransactions).toFixed(2)}
                </small>
              </span>
            } 
            key="all"
          >
            <Table
              dataSource={allTransactions}
              columns={columns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10, showSizeChanger: true }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane 
            tab={
              <span>
                Pending ({pendingTransactions.length})
                <br />
                <small style={{ color: '#faad14' }}>
                  Total: ${calculateTotal(pendingTransactions).toFixed(2)}
                </small>
              </span>
            } 
            key="pending"
          >
            <Table
              dataSource={pendingTransactions}
              columns={columns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10, showSizeChanger: true }}
              scroll={{ x: true }}
            />
          </TabPane>

          <TabPane 
            tab={
              <span>
                Completed ({completedTransactions.length})
                <br />
                <small style={{ color: '#52c41a' }}>
                  Total: ${calculateTotal(completedTransactions).toFixed(2)}
                </small>
              </span>
            } 
            key="completed"
          >
            <Table
              dataSource={completedTransactions}
              columns={columns}
              rowKey="id"
              loading={loading}
              pagination={{ pageSize: 10, showSizeChanger: true }}
              scroll={{ x: true }}
            />
          </TabPane>
        </Tabs>
      </Card>
    </div>
  );
};

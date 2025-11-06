# 📊 E-Commerce System - Entity Relationship Diagram

## Database Schema Overview

This document provides a comprehensive Entity Relationship Diagram (ERD) for the e-commerce system's Firestore database structure.

---

## 🗂️ Collections and Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         E-COMMERCE DATABASE SCHEMA                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│      users       │◄──────────────────────┐
├──────────────────┤                       │
│ PK  id           │                       │
│     name         │                       │
│     email        │                       │
│     role         │                       │ (user_id)
│     password     │                       │
│     status       │                       │
│     phone        │                       │
│     location     │                       │
│     image_path   │                       │
│     cooperativeId│──┐                    │
│     created_at   │  │                    │
│     updated_at   │  │                    │
└──────────────────┘  │                    │
         │            │                    │
         │ (id)       │                    │
         │            │                    │
         ▼            │                    │
┌──────────────────┐  │                    │
│     sellers      │  │                    │
├──────────────────┤  │                    │
│ PK  id           │  │                    │
│ FK  user_id      │  │                    │
│     name         │  │                    │
│     email        │  │                    │
│     contact_num  │  │                    │
│     username     │  │                    │
│     password     │  │                    │
│     image_path   │  │                    │
│     cooperativeId│──┤                    │
│     status       │  │                    │
│     created_at   │  │                    │
│     updated_at   │  │  (cooperativeId)  │
└──────────────────┘  │                    │
         │            │                    │
         │ (seller_id)│                    │
         │            ▼                    │
         │   ┌──────────────────┐         │
         │   │  cooperatives    │         │
         │   ├──────────────────┤         │
         │   │ PK  id           │         │
         │   │     name         │         │
         │   │     email        │         │
         │   │     phone        │         │
         │   │     location     │         │
         │   │     role         │         │
         │   │     status       │         │
         │   │     created_at   │         │
         │   │     updated_at   │         │
         │   └──────────────────┘         │
         │                                 │
         ▼                                 │
┌──────────────────┐                      │
│    products      │                      │
├──────────────────┤                      │
│ PK  id           │                      │
│ FK  seller_id    │                      │
│ FK  category_id  │──┐                   │
│     name         │  │                   │
│     description  │  │                   │
│     price        │  │                   │
│     stock        │  │                   │
│     status       │  │                   │
│     cooperativeId│  │                   │
│     created_at   │  │                   │
│     updated_at   │  │  (category_id)   │
└──────────────────┘  │                   │
         │            │                   │
         │            ▼                   │
         │   ┌──────────────────┐        │
         │   │   categories     │        │
         │   ├──────────────────┤        │
         │   │ PK  id           │        │
         │   │     name         │        │
         │   │     image_path   │        │
         │   │     created_at   │        │
         │   │     updated_at   │        │
         │   └──────────────────┘        │
         │                                │
         │ (product_id)                   │
         │                                │
         ├──────────────┬─────────────────┼──────────────┐
         │              │                 │              │
         ▼              ▼                 ▼              ▼
┌──────────────────┐ ┌──────────────┐ ┌────────────┐ ┌──────────────────┐
│ product_images   │ │    carts     │ │  wishlist  │ │ product_reviews  │
├──────────────────┤ ├──────────────┤ ├────────────┤ ├──────────────────┤
│ PK  id           │ │ PK  id       │ │ PK  id     │ │ PK  id           │
│ FK  product_id   │ │ FK  user_id  │ │ FK user_id │ │ FK  user_id      │
│     image_path   │ │ FK  product_id│ │ FK product_│ │ FK  product_id   │
│     created_at   │ │     quantity │ │     _id    │ │ FK  order_id     │
│     updated_at   │ │     created_at│ │ created_at │ │     rate         │
└──────────────────┘ │     updated_at│ │ updated_at │ │     description  │
                     └──────────────┘ └────────────┘ │     created_at   │
                                                      │     updated_at   │
                                                      └──────────────────┘

┌──────────────────┐
│      orders      │
├──────────────────┤
│ PK  id           │
│ FK  buyer_id     │───────────────┐
│ FK  seller_id    │───────┐       │
│     productId    │       │       │
│     productName  │       │       │ (references users)
│     productImage │       │       │
│     quantity     │       │       │
│     price        │       │       │
│     totalAmount  │       │       │
│     status       │       │       │
│     deliveryMethod│      │       │
│     pickupLocation│      │       │
│     paymentMethod│       │       │
│     created_at   │       │       │
│     updated_at   │       │       │
└──────────────────┘       │       │
         │                 │       │
         │                 │       │
         ├─────────────────┘       │
         │                         │
         │ (order_id)             │
         │                         │
         ▼                         │
┌──────────────────┐              │
│   order_items    │              │
├──────────────────┤              │
│ PK  id           │              │
│ FK  order_id     │              │
│     productId    │              │
│     productName  │              │
│     quantity     │              │
│     price        │              │
│     created_at   │              │
│     updated_at   │              │
└──────────────────┘              │
                                  │
                                  │
┌──────────────────┐              │
│  reservations    │              │
├──────────────────┤              │
│ PK  id           │              │
│ FK  user_id      │──────────────┤
│ FK  seller_id    │──────────────┘
│ FK  product_id   │
│     productName  │
│     quantity     │
│     price        │
│     totalAmount  │
│     status       │
│     pickupDate   │
│     timestamp    │
└──────────────────┘


┌──────────────────┐
│  notifications   │
├──────────────────┤
│ PK  id           │
│ FK  user_id      │──────────────┐
│     title        │              │
│     message      │              │ (references users)
│     type         │              │
│     read         │              │
│     priority     │              │
│     orderId      │              │
│     productId    │              │
│     timestamp    │              │
│     created_at   │              │
└──────────────────┘              │
                                  │
┌──────────────────────────┐     │
│  seller_notifications    │     │
├──────────────────────────┤     │
│ PK  id                   │     │
│ FK  seller_id            │─────┤
│     order_id             │     │
│     product_id           │     │
│     productName          │     │
│     quantity             │     │
│     totalAmount          │     │
│     status               │     │
│     type                 │     │
│     message              │     │
│     timestamp            │     │
└──────────────────────────┘     │
                                  │
┌──────────────────────────┐     │
│ cooperative_notifications│     │
├──────────────────────────┤     │
│ PK  id                   │     │
│ FK  cooperativeId        │     │
│     title                │     │
│     message              │     │
│     type                 │     │
│     seller_id            │     │
│     product_id           │     │
│     priority             │     │
│     read                 │     │
│     created_at           │     │
└──────────────────────────┘     │
                                  │
┌──────────────────────────┐     │
│   user_notifications     │     │
├──────────────────────────┤     │
│ PK  id                   │     │
│ FK  user_id              │─────┤
│     title                │     │
│     message              │     │
│     type                 │     │
│     product_id           │     │
│     priority             │     │
│     read                 │     │
│     created_at           │     │
└──────────────────────────┘     │
                                  │
┌──────────────────────────┐     │
│ buyer_product_alerts     │     │
├──────────────────────────┤     │
│ PK  id                   │     │
│     product_id           │     │
│     productName          │     │
│     sellerName           │     │
│     category             │     │
│     price                │     │
│     type                 │     │
│     timestamp            │     │
└──────────────────────────┘     │
                                  │
┌──────────────────────────┐     │
│ seller_market_updates    │     │
├──────────────────────────┤     │
│ PK  id                   │     │
│     product_id           │     │
│     productName          │     │
│     sellerName           │     │
│     category             │     │
│     excludeSellerId      │─────┘
│     type                 │
│     timestamp            │
└──────────────────────────┘


┌──────────────────┐
│  transactions    │
├──────────────────┤
│ PK  id           │
│ FK  buyer_id     │──────────────┐
│ FK  seller_id    │──────────┐   │
│     order_id     │          │   │
│     amount       │          │   │ (references users)
│     paymentMethod│          │   │
│     status       │          │   │
│     created_at   │          │   │
│     updated_at   │          │   │
└──────────────────┘          │   │
                              │   │
┌──────────────────┐          │   │
│ gcash_payments   │          │   │
├──────────────────┤          │   │
│ PK  id           │          │   │
│ FK  user_id      │──────────┼───┘
│     order_id     │          │
│     amount       │          │
│     referenceNum │          │
│     status       │          │
│     created_at   │          │
│     updated_at   │          │
└──────────────────┘          │
                              │
┌──────────────────┐          │
│paymongo_payments │          │
├──────────────────┤          │
│ PK  id           │          │
│ FK  user_id      │──────────┘
│     order_id     │
│     amount       │
│     paymentIntent│
│     status       │
│     created_at   │
│     updated_at   │
└──────────────────┘


┌──────────────────┐
│      chats       │
├──────────────────┤
│ PK  id           │
│ FK  seller_id    │──────────────┐
│ FK  customer_id  │──────────┐   │
│     lastMessage  │          │   │ (references users)
│     lastMessageAt│          │   │
│     created_at   │          │   │
│     updated_at   │          │   │
└──────────────────┘          │   │
         │                    │   │
         │ (chat_id)         │   │
         │                    │   │
         ▼                    │   │
┌──────────────────┐          │   │
│    messages      │          │   │
├──────────────────┤          │   │
│ PK  id           │          │   │
│ FK  chat_id      │          │   │
│ FK  sender_id    │──────────┴───┘
│     message      │
│     timestamp    │
│     read         │
└──────────────────┘


┌──────────────────┐
│ seller_ratings   │
├──────────────────┤
│ PK  id           │
│ FK  seller_id    │──────────────┐
│ FK  buyer_id     │──────────┐   │
│     rating       │          │   │ (references users)
│     review       │          │   │
│     order_id     │          │   │
│     created_at   │          │   │
│     updated_at   │          │   │
└──────────────────┘          │   │
                              │   │
┌──────────────────┐          │   │
│ review_reports   │          │   │
├──────────────────┤          │   │
│ PK  id           │          │   │
│     rating_id    │          │   │
│ FK  reported_by  │──────────┴───┘
│     reason       │
│     description  │
│     status       │
│     created_at   │
└──────────────────┘


┌──────────────────┐
│ user_feedback    │
├──────────────────┤
│ PK  id           │
│ FK  user_id      │──────────────┐
│     type         │              │
│     subject      │              │ (references users)
│     message      │              │
│     status       │              │
│     response     │              │
│     created_at   │              │
│     updated_at   │              │
└──────────────────┘              │
                                  │
┌──────────────────┐              │
│ product_updates  │              │
├──────────────────┤              │
│ PK  id           │              │
│     product_id   │              │
│     productName  │              │
│     seller_id    │──────────────┘
│     changeType   │
│     oldValue     │
│     newValue     │
│     timestamp    │
└──────────────────┘


┌──────────────────┐
│  shipping_rates  │
├──────────────────┤
│ PK  id           │
│     weight_min   │
│     weight_max   │
│     isbon        │
│     visayas      │
│     mindanao     │
│     created_at   │
│     updated_at   │
└──────────────────┘
```

---

## 🔑 Key Relationships

### Primary Relationships

1. **Users ↔ Sellers** (1:1)
   - One user can be one seller
   - Linked via `user_id`

2. **Users ↔ Cooperatives** (N:1)
   - Multiple users can belong to one cooperative
   - Multiple sellers can belong to one cooperative
   - Linked via `cooperativeId`

3. **Sellers ↔ Products** (1:N)
   - One seller can have many products
   - Linked via `seller_id`

4. **Products ↔ Categories** (N:1)
   - Many products belong to one category
   - Linked via `category_id`

5. **Products ↔ Product Images** (1:N)
   - One product can have multiple images
   - Linked via `product_id`

6. **Users ↔ Carts** (1:N)
   - One user can have multiple cart items
   - Linked via `user_id`

7. **Products ↔ Carts** (1:N)
   - One product can be in multiple carts
   - Linked via `product_id`

8. **Users ↔ Orders** (1:N as buyer, 1:N as seller)
   - One user can create many orders (as buyer)
   - One seller can receive many orders
   - Linked via `buyer_id` and `seller_id`

9. **Orders ↔ Order Items** (1:N)
   - One order can have multiple items
   - Linked via `order_id`

10. **Users ↔ Reservations** (1:N)
    - One user can make multiple reservations
    - Linked via `user_id` and `seller_id`

### Notification Relationships

11. **Users ↔ Notifications** (1:N)
    - One user receives many notifications
    - Linked via `user_id`

12. **Sellers ↔ Seller Notifications** (1:N)
    - One seller receives many notifications
    - Linked via `seller_id`

13. **Cooperatives ↔ Cooperative Notifications** (1:N)
    - One cooperative receives many notifications
    - Linked via `cooperativeId`

### Payment & Transaction Relationships

14. **Users ↔ Transactions** (1:N)
    - One user can have multiple transactions
    - Linked via `buyer_id` and `seller_id`

15. **Users ↔ GCash Payments** (1:N)
    - One user can make multiple GCash payments
    - Linked via `user_id`

16. **Users ↔ Paymongo Payments** (1:N)
    - One user can make multiple Paymongo payments
    - Linked via `user_id`

### Communication & Review Relationships

17. **Users ↔ Chats** (1:N)
    - One user can have multiple chats
    - Linked via `seller_id` and `customer_id`

18. **Chats ↔ Messages** (1:N)
    - One chat contains many messages
    - Linked via `chat_id`

19. **Users ↔ Seller Ratings** (1:N)
    - One buyer can rate multiple sellers
    - Linked via `buyer_id` and `seller_id`

20. **Users ↔ Product Reviews** (1:N)
    - One user can write multiple reviews
    - Linked via `user_id`

21. **Users ↔ Wishlist** (1:N)
    - One user can have multiple wishlist items
    - Linked via `user_id`

---

## 📋 Collection Details

### Core Collections

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **users** | id | - | User accounts (buyers, sellers, cooperatives, admin) |
| **sellers** | id | user_id, cooperativeId | Seller profiles and business info |
| **products** | id | seller_id, category_id | Product catalog |
| **categories** | id | - | Product categories |
| **product_images** | id | product_id | Product image gallery |

### Shopping & Orders

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **carts** | id | user_id, product_id | Shopping cart items |
| **orders** | id | buyer_id, seller_id | Order records |
| **order_items** | id | order_id | Items within an order |
| **reservations** | id | user_id, seller_id, product_id | Product reservations |
| **wishlist** | id | user_id, product_id | User wishlist |

### Notifications

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **notifications** | id | user_id | General user notifications |
| **seller_notifications** | id | seller_id | Seller-specific notifications |
| **cooperative_notifications** | id | cooperativeId | Cooperative notifications |
| **user_notifications** | id | user_id | User account notifications |
| **buyer_product_alerts** | id | - | Product alerts for buyers |
| **seller_market_updates** | id | excludeSellerId | Market updates for sellers |
| **product_updates** | id | product_id, seller_id | Product change tracking |

### Payments & Transactions

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **transactions** | id | buyer_id, seller_id | Transaction records |
| **gcash_payments** | id | user_id | GCash payment records |
| **paymongo_payments** | id | user_id | Paymongo payment records |

### Communication & Reviews

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **chats** | id | seller_id, customer_id | Chat conversations |
| **messages** | id | chat_id, sender_id | Chat messages |
| **seller_ratings** | id | seller_id, buyer_id | Seller ratings and reviews |
| **product_reviews** | id | user_id, product_id, order_id | Product reviews |
| **review_reports** | id | reported_by | Reported reviews |

### Support & Logistics

| Collection | Primary Key | Foreign Keys | Description |
|------------|------------|--------------|-------------|
| **user_feedback** | id | user_id | User feedback and support tickets |
| **shipping_rates** | id | - | Shipping rate configurations |

---

## 🎯 Field Conventions

### Common Fields Across Collections

- **id**: Unique identifier (Primary Key)
- **created_at**: Timestamp when record was created
- **updated_at**: Timestamp when record was last updated
- **status**: Record status (pending, approved, rejected, active, etc.)

### User-Related Fields

- **user_id**: Reference to users collection
- **buyer_id**: Reference to users collection (buyer role)
- **seller_id**: Reference to sellers/users collection (seller role)
- **cooperativeId**: Reference to cooperative account

### Product-Related Fields

- **product_id**: Reference to products collection
- **productName**: Product name
- **price**: Product price
- **quantity**: Product quantity
- **stock**: Available stock

### Order-Related Fields

- **order_id**: Reference to orders collection
- **totalAmount**: Total order amount
- **deliveryMethod**: Delivery method selected
- **paymentMethod**: Payment method selected

---

## 🔒 Security Rules Summary

All collections have security rules enforced at the Firestore level:

1. **Authentication Required**: All operations require authenticated users
2. **Role-Based Access**: Admin, Cooperative, Seller, and Buyer roles have different permissions
3. **Owner-Only Access**: Users can only access their own data
4. **Read/Write Separation**: Separate rules for reading and writing data
5. **Field-Level Validation**: Specific fields can only be updated by authorized users

---

## 📊 Data Flow Summary

### Order Flow
```
User → Cart → Order → Order Items → Seller Notification → Transaction → Payment
```

### Product Flow
```
Seller → Products → Product Images → Category → Approval (if cooperative) → Published
```

### Notification Flow
```
Event → Notification Creation → User/Seller/Cooperative Notification → Read Status Update
```

### Communication Flow
```
Customer/Seller → Chat → Messages → Read Status
```

---

## 🏷️ Indexes Required

For optimal query performance, the following indexes should be configured:

1. **products**: `seller_id`, `status`, `category_id`
2. **orders**: `buyer_id`, `seller_id`, `status`, `created_at`
3. **notifications**: `user_id`, `read`, `timestamp`
4. **seller_notifications**: `seller_id`, `status`, `timestamp`
5. **chats**: `seller_id`, `customer_id`, `lastMessageAt`
6. **messages**: `chat_id`, `timestamp`
7. **reservations**: `user_id`, `seller_id`, `status`

---

## 📝 Notes

- All timestamps use Firestore's `serverTimestamp()` function
- Subcollections are used for nested data (e.g., order_items within orders)
- Foreign key relationships are enforced through application logic, not database constraints
- Cooperative role has special approval permissions for sellers and products
- Multiple notification collections handle different user types and scenarios
- Payment integration supports both GCash and Paymongo

---

**Last Updated**: November 3, 2025
**Database Type**: Cloud Firestore (NoSQL)
**Application**: E-Commerce Mobile App (Flutter)

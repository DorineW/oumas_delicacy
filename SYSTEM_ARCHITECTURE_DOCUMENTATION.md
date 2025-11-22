# Ouma's Delicacy - System Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture Components](#architecture-components)
4. [Data Models](#data-models)
5. [Service Layer](#service-layer)
6. [State Management (Providers)](#state-management-providers)
7. [Backend Infrastructure](#backend-infrastructure)
8. [System Flow](#system-flow)
9. [Payment Integration](#payment-integration)
10. [Security & Offline Capabilities](#security--offline-capabilities)

---

## System Overview

Ouma's Delicacy is a comprehensive food ordering and general store application built with Flutter and Supabase. The system supports:
- **Restaurant operations** (menu management, meal ordering)
- **General store operations** (product inventory management)
- **M-Pesa payment integration** (Safaricom mobile payments)
- **Real-time order tracking** via Supabase subscriptions
- **Offline-first capabilities** with local caching
- **Automated receipt generation** (stored in database, email delivery not yet implemented)
- **Android platform** (iOS and Web not yet deployed)

### User Roles
- **Admin**: Full system management, menu/store management, order oversight, rider assignment
- **Customer**: Browse menu/store, add to cart, place orders, track deliveries, manage addresses
- **Rider**: View assigned deliveries, navigate to customers, update delivery status

---

## Technology Stack

### Frontend
- **Flutter**: Mobile app framework (currently deployed on Android only)
- **Provider Pattern**: State management for reactive UI
- **Supabase Flutter SDK**: Backend integration and real-time subscriptions

### Backend
- **Supabase**: Backend-as-a-Service platform
  - PostgreSQL database with Row Level Security (RLS) policies
  - Real-time subscriptions for live order updates
  - Edge Functions (Deno) for serverless payment processing
  - Authentication system with JWT tokens

### External Services
- **M-Pesa (Safaricom Daraja API)**: Mobile money payments via STK Push
- **OpenStreetMap**: Map display and address selection (not Google Maps)
- **Resend API**: Email infrastructure (configured but email delivery not yet functional)

---

## Architecture Components

### 1. Models (`lib/models/`)

Data classes represent business entities in the application. All models use **UUID (Universally Unique Identifier)** for primary keys, which provides:
- **Global uniqueness**: No ID collisions across distributed systems
- **Security**: IDs are non-sequential, preventing enumeration attacks
- **Offline generation**: Can create records offline without database coordination
- **128-bit identifiers**: Supabase PostgreSQL's `uuid` type

**Core Business Models:**

- **`menu_item.dart`**: Restaurant menu items with meal weight options
- **`store_item.dart`**: General store products with flexible unit descriptions and inventory tracking
- **`order.dart`**: Customer orders with comprehensive status tracking workflow
- **`cart_item.dart`**: Shopping cart items (in-memory only, persisted to SharedPreferences)
- **`user.dart`**: User profiles with role-based access control
- **`user_address.dart`**: Customer saved delivery addresses with GPS coordinates
- **`location.dart`**: Business location data (single location system, no multi-location support)
- **`product_inventory.dart`**: Real-time stock levels and restock tracking
- **`receipt.dart`**: Payment receipts generated after successful transactions
- **`delivery_order.dart`**: Rider delivery assignments and tracking
- **`notification_model.dart`**: In-app notifications

### 2. Services (`lib/services/`)
Business logic and external API communication:

- **`auth_service.dart`**: 
  - User authentication (login, register, logout)
  - Password reset with rate limiting
  - Profile management with local caching
  - Role-based access control

- **`mpesa_service.dart`**:
  - STK Push initiation
  - Phone number formatting (254XXXXXXXXX)
  - Payment status tracking
  - Transaction polling

- **`receipt_service.dart`**:
  - Fetch receipts by order or transaction ID
  - Receipt data with line items
  - Receipt stored in database (PDF/email functionality pending)

- **`chat_service.dart`**:
  - Real-time customer-admin messaging
  - Message persistence in Supabase
  - Unread count tracking

- **`location_service.dart`**:
  - GPS location access via device
  - Distance calculations using Haversine formula
  - Single business location system (no multi-location zones)

- **`notification_service.dart`**:
  - Push notification handling
  - In-app notification display
  - Order status notifications

### 3. Providers (`lib/providers/`)
State management using Flutter Provider pattern:

- **`menu_provider.dart`**:
  - Load menu items from database
  - Category filtering
  - Availability status
  - Popular items calculation

- **`store_provider.dart`**:
  - Load store items with inventory
  - Stock level tracking (out of stock, low stock, in stock)
  - Availability checking
  - Inventory-aware item display

- **`cart_provider.dart`**:
  - Add/remove items
  - Quantity management
  - Total calculation
  - Cart persistence

- **`order_provider.dart`**:
  - Order creation and submission
  - Real-time order status updates via Supabase subscriptions
  - Order history with caching
  - Rider assignment tracking

- **`inventory_provider.dart`**:
  - Stock level management
  - Low stock alerts
  - Restock operations
  - Multi-product inventory tracking

- **`location_management_provider.dart`**:
  - Business location management (single primary location)
  - Delivery fee configuration
  - Basic location settings (no multi-zone support)

- **`address_provider.dart`**:
  - Customer address management
  - Default address selection
  - Delivery address validation

- **`favorites_provider.dart`**:
  - Save favorite menu and store items
  - Quick reorder functionality

- **`mpesa_provider.dart`**:
  - Payment initiation orchestration
  - Real-time payment status updates
  - Transaction history

- **`receipt_provider.dart`**:
  - Receipt fetching and display
  - Email receipt delivery status

- **`reviews_provider.dart`**:
  - Product and order ratings
  - Review submission
  - Review moderation

- **`notification_provider.dart`**:
  - Notification badge management
  - Mark as read functionality

- **`connectivity_provider.dart`**:
  - Network status monitoring
  - Offline mode detection
  - Sync queue management

### 4. Utilities (`lib/utils/`)
Helper functions and shared components:

- **`phone_utils.dart`**: Phone number validation and formatting
- **`responsive_helper.dart`**: Responsive UI utilities
- **`error_snackbar.dart`**: Standardized error display

### 5. Screens (`lib/screens/`)
User interface organized by role:

#### Customer Screens
- **`home_screen.dart`**: Menu browsing, featured items
- **`store_screen.dart`**: General store product browsing
- **`meal_detail_screen.dart`**: Menu item details with customization
- **`cart_screen.dart`**: Shopping cart review
- **`checkout_screen.dart`**: Delivery address selection, payment initiation
- **`order_history_screen.dart`**: Past orders with reorder
- **`customer_chat_screen.dart`**: Support messaging
- **`customer_address_management_screen.dart`**: Address CRUD
- **`profile_screen.dart`**: User profile, favorites, settings
- **`notifications_screen.dart`**: Notification center

#### Admin Screens (`lib/screens/admin/`)
- **`admin_dashboard_screen.dart`**: Analytics, order overview
- **`admin_menu_management_screen.dart`**: Menu item CRUD
- **`admin_store_management_screen.dart`**: Store product CRUD
- **`admin_inventory_management_screen.dart`**: Stock management, restock operations
- **`admin_location_management_screen.dart`**: Business location configuration
- **`manage_orders_screen.dart`**: Order processing, rider assignment
- **`admin_chat_list_screen.dart`**: Customer support inbox
- **`mpesa_management_screen.dart`**: Payment reconciliation, transaction logs
- **`manage_users_screen.dart`**: User role management
- **`reports_screen.dart`**: Sales reports, analytics

#### Rider Screens (`lib/screens/rider/`)
- **`rider_dashboard_screen.dart`**: Assigned deliveries
- **`delivery_map_screen.dart`**: Navigation to customer
- **`delivery_proof_screen.dart`**: Delivery confirmation

#### Authentication Screens
- **`login_screen.dart`**: Email/password login (default entry point)
- **`register_screen.dart`**: New user registration with Terms & Conditions acceptance
- **`forgot_password_screen.dart`**: Password reset flow
- **`onboarding_screen.dart`**: First-time user tutorial (shown after successful authentication if not seen before)

---

## Data Models

All data models use **UUIDs (Universally Unique Identifiers)** as primary keys. UUIDs provide:
- **Global uniqueness** without database coordination
- **Security** through non-sequential IDs
- **Offline capability** for creating records before syncing
- **128-bit identifiers** managed by PostgreSQL

### Core Business Entities

#### MenuItem
Represents restaurant menu items offered to customers. Includes meal weight categories (Light, Medium, Heavy) for portion size selection. Links to a product record via UUID for inventory tracking.

#### StoreItem
Represents general store products with flexible unit descriptions (e.g., "500g", "2L", "1 Dozen"). Features optional inventory tracking - items can be marked for stock monitoring or sold without quantity limits.

#### Order
Comprehensive order records tracking the entire customer journey. Includes a human-readable short ID for customer reference, delivery address as JSONB for flexibility, and GPS coordinates for rider navigation. Status workflow: pending_payment → confirmed → preparing → outForDelivery → delivered.

#### OrderItem
Individual line items within orders, linking back to menu items via UUID while storing snapshot data (name, price) to preserve order history even if menu items are later modified or deleted.

#### CartItem
In-memory representation of shopping cart items. Uses menu item UUID for reference. Persisted to local device storage (SharedPreferences) for cart recovery across app sessions.

#### User
User profiles with role-based access (admin, customer, rider). Stores authentication details, contact information, and preferences. UUID links to Supabase Auth system.

#### UserAddress
Customer-saved delivery addresses with GPS coordinates for accurate delivery. Includes formatted address string from OpenStreetMap and default address flag for quick checkout.

#### Location
Business location information for the single primary restaurant/store. Contains delivery settings, business contact details, and GPS coordinates. System uses one active location (no multi-location support).

#### ProductInventory
Real-time stock tracking for store items. Includes current quantity, minimum stock alert threshold, and last restock date. Links to products via UUID.

#### Receipt
Payment receipts generated automatically after successful M-Pesa transactions. Contains business and customer details, itemized list, tax breakdown, and links to transaction via UUID.

#### DeliveryOrder
Rider assignment records linking orders to riders. Tracks delivery status, pickup/dropoff times, and rider notes.

#### NotificationModel
In-app notification records for order updates, system announcements, and promotional messages. Includes read/unread status and timestamp.

---

## Service Layer

### Authentication Service
Handles user authentication and session management:
- **Login/Register**: Email-password authentication via Supabase Auth
- **Rate Limiting**: In-memory cooldown for password reset (60s window)
- **Profile Caching**: SharedPreferences for offline profile access
- **Role Validation**: Admin, customer, rider role checks

### M-Pesa Service
Mobile money payment integration:
- **Phone Formatting**: Converts various formats to 254XXXXXXXXX
- **STK Push**: Initiates payment via Supabase Edge Function
- **Payment Polling**: Checks transaction status in real-time
- **Transaction Tracking**: Links payments to orders

### Receipt Service
Receipt generation and retrieval:
- **Fetch by Order**: Retrieves receipt after successful payment
- **Fetch by Transaction**: Direct transaction lookup using M-Pesa transaction ID
- **Database Storage**: Receipts stored in `receipts` table with line items
- **Email Delivery**: Infrastructure configured but not yet functional

### Location Service
GPS and delivery management:
- **Distance Calculation**: Haversine formula for calculating delivery distance
- **Location Access**: Device GPS for customer address entry
- **Single Location System**: One primary business location (no multi-location zones)
- **Fee Calculation**: Simple delivery fee based on distance

---

## State Management (Providers)

The application uses Flutter's Provider pattern for state management, ensuring:
- **Reactive UI**: Widgets rebuild automatically when data changes
- **Separation of Concerns**: Business logic separated from UI
- **Testability**: Providers can be mocked for testing
- **Performance**: Selective widget rebuilding

### Key Provider Features

#### Order Provider with Real-time Updates
```dart
// Listens to Supabase real-time changes
_supabase
  .from('orders')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Update order list
    notifyListeners();
  });
```

#### Cart Provider with Persistence
```dart
// Saves cart to local storage
void addItem(CartItem item) {
  _items.add(item);
  _saveToCache();
  notifyListeners();
}
```

#### Inventory Provider with Stock Alerts
```dart
bool get isOutOfStock => trackInventory && currentStock == 0;
bool get isLowStock => trackInventory && currentStock > 0 && currentStock <= 10;
```

---

## Backend Infrastructure

### Supabase PostgreSQL Database

The database uses PostgreSQL with Row Level Security (RLS) policies for access control. All tables use UUID primary keys for security and distributed system compatibility.

#### Key Tables:

**users** - User profiles linked to Supabase Auth
- Stores: full name, email, phone, role (admin/customer/rider)
- Links: auth_id → Supabase Auth user

**menu_items** - Restaurant menu offerings
- Stores: name, price, category, meal weight, availability status
- Links: product_id → general products table

**StoreItems** - General store products
- Stores: name, price, unit description, inventory tracking flag
- Optional inventory tracking per item

**ProductInventory** - Stock tracking
- Stores: current quantity, minimum alert threshold, last restock date
- Links: product_id → StoreItems or menu_items

**orders** - Customer orders
- Stores: customer ID, status, totals, delivery address (JSONB), timestamps
- Status workflow: pending_payment → confirmed → preparing → outForDelivery → delivered
- Links: user_auth_id → users, rider_id → users, delivery_address_id → UserAddresses

**order_items** - Order line items
- Stores: item name, quantity, unit price, total price
- Links: order_id → orders, product_id → menu_items

**mpesa_transactions** - M-Pesa payment records
- Stores: transaction ID, amount, phone number, status, timestamps
- Links: order_id → orders, user_auth_id → users
- Tracks: checkout_request_id, merchant_request_id for payment reconciliation

**receipts** - Payment receipts
- Stores: receipt number, customer details, business details, totals
- Generated automatically after successful payment
- Links: transaction_id → mpesa_transactions

**receipt_items** - Receipt line items
- Stores: item description, quantity, prices
- Links: receipt_id → receipts

**UserAddresses** - Customer saved addresses
- Stores: formatted address, GPS coordinates (lat/lon), default flag
- Links: user_auth_id → users
- Address data from OpenStreetMap

**locations** - Business location (single location system)
- Stores: business name, address, contact info, delivery settings
- Single active location (no multi-location support currently)

**chat_messages** - Customer support messaging
- Stores: message text, sender, timestamps, read status
- Real-time updates via Supabase subscriptions
- Links: user_auth_id → users

**notifications** - In-app notifications
- Stores: notification text, type, read status, timestamps
- Links: user_auth_id → users

**favorites** - User favorite items
- Stores: references to menu or store items
- Links: user_auth_id → users, item_id → menu_items or StoreItems

### Supabase Edge Functions (Deno)

#### **mpesa-stk-push**
- **Purpose**: Initiates M-Pesa STK Push to customer's phone
- **Flow**:
  1. Receives payment request from Flutter app
  2. Formats phone number
  3. Obtains M-Pesa access token from Safaricom OAuth API
  4. Generates timestamp and password
  5. Calls Safaricom STK Push API
  6. Creates pending transaction record in `mpesa_transactions` table
  7. Returns checkout request ID to app

**Environment Variables**:
- `MPESA_CONSUMER_KEY`
- `MPESA_CONSUMER_SECRET`
- `MPESA_SHORTCODE`
- `MPESA_PASSKEY`
- `MPESA_CALLBACK_URL`

#### **mpesa-callback**
- **Purpose**: Receives payment confirmation webhook from Safaricom
- **Flow**:
  1. Safaricom posts callback after customer completes payment
  2. Extracts transaction details (receipt number, amount, phone, timestamp)
  3. Updates `mpesa_transactions` status (completed/failed)
  4. If successful and linked to order:
     - Updates order status to 'confirmed'
     - Generates receipt in `receipts` table
     - Creates receipt line items in `receipt_items`
     - Email sending configured but not yet functional
  5. Returns success response to Safaricom

**Key Features**:
- Idempotent: Handles duplicate callbacks gracefully
- Automatic receipt generation and database storage
- Comprehensive error handling and logging
- Email infrastructure configured (Resend API) but delivery not active

### Real-time Subscriptions
Supabase Realtime enables live updates:
- **Order status changes**: Customers see instant updates
- **Chat messages**: Live messaging between customer and admin
- **Payment confirmations**: UI updates when callback processed
- **Inventory changes**: Stock levels reflect immediately

### Row Level Security (RLS)
PostgreSQL Row Level Security enforces access control at the database level:
- **Customers**: Can only view/edit their own orders, addresses, and favorites
- **Admins**: Full access to all tables for management
- **Riders**: Can only view orders assigned to them
- **Public**: Read-only access to menu items and store items (for browsing)
- **Authenticated**: Users can create orders and addresses for themselves

---

## System Flow

### Admin Flow: Adding Menu Items and Store Products

#### 1. Admin Authentication
```
Admin logs in → AuthService validates credentials 
→ Supabase Auth verifies → Role checked (must be 'admin')
→ Admin dashboard loads
```

#### 2. Adding Menu Items (Restaurant)
```
Admin navigates to Menu Management Screen
↓
Clicks "Add Menu Item"
↓
Fills form:
  - Name (e.g., "Ugali with Fish")
  - Category (e.g., "Main Course")
  - Price (e.g., 300 Ksh)
  - Meal Weight (Light/Medium/Heavy)
  - Description
  - Upload image
  - Set availability
↓
Submits form → MenuProvider.addMenuItem()
↓
Data inserted into 'menu_items' table (Supabase)
↓
Real-time subscription updates → All connected clients see new item
↓
Success message displayed
```

**Database Operation**:
```sql
INSERT INTO menu_items (product_id, name, price, category, meal_weight, description, image_url, available)
VALUES (...);
```

#### 3. Adding Store Items (General Store)
```
Admin navigates to Store Management Screen
↓
Clicks "Add Store Item"
↓
Fills form:
  - Name (e.g., "Cooking Oil")
  - Category (e.g., "Groceries")
  - Price (e.g., 450 Ksh)
  - Unit Description (e.g., "2 Liters")
  - Track Inventory? (Yes/No checkbox)
  - If Yes: Initial Stock Quantity (e.g., 50)
  - Upload image
  - Set availability
↓
Submits form → StoreProvider.addStoreItem()
↓
Transaction begins:
  1. Insert into 'StoreItems' table
  2. If track_inventory = true:
     Insert into 'ProductInventory' table with initial quantity
↓
Real-time subscription updates → Inventory displays
↓
Success message displayed
```

**Database Operations**:
```sql
-- Step 1: Create store item
INSERT INTO StoreItems (product_id, name, price, category, unit_description, track_inventory, available)
VALUES (...);

-- Step 2: Initialize inventory (if tracking enabled)
INSERT INTO ProductInventory (product_id, quantity, minimum_stock_alert, last_restock_date)
VALUES (...);
```

#### 4. Managing Inventory
```
Admin navigates to Inventory Management Screen
↓
Views all products with current stock levels
↓
Identifies low stock items (highlighted in yellow/red)
↓
Clicks "Restock" on an item
↓
Enters restock quantity (e.g., +30 units)
↓
InventoryProvider.restockItem()
↓
Updates 'ProductInventory' table:
  - Increments quantity
  - Updates last_restock_date
↓
If quantity exceeds minimum_stock_alert → Alert dismissed
↓
Real-time update → Stock level changes reflect immediately
```

**Database Operation**:
```sql
UPDATE ProductInventory
SET quantity = quantity + 30,
    last_restock_date = NOW()
WHERE product_id = '...';
```

---

### Customer Flow: From Browsing to Order Delivery

#### 1. Customer Registration/Login
```
Customer opens app → Login Screen (default entry point)
↓
Option 1: Login
  - Enters email and password
  - AuthService.login() called
  - Supabase Auth validates credentials
  - Profile loaded from 'users' table
  - Checks if user has seen onboarding before

Option 2: Register
  - Clicks "Create Account"
  - Fills registration form (name, email, phone, password)
  - MUST accept Terms & Conditions (checkbox required)
  - AuthService.register() called
  - Supabase Auth creates account
  - Profile created in 'users' table with 'customer' role
↓
If first time using app after authentication:
  - Onboarding screens shown (tutorial/introduction)
  - Swipe through feature highlights
  - Marked as complete in SharedPreferences
↓
Home screen displays with menu items
```

#### 2. Browsing Menu/Store
```
Home Screen loads
↓
MenuProvider.loadMenuItems() called
↓
Supabase query: SELECT * FROM menu_items WHERE available = true
↓
Items displayed by category (Main Course, Drinks, Desserts, etc.)
↓
Customer can:
  - Filter by category
  - View popular items (top 5 by price)
  - Search by name
↓
Customer navigates to Store tab
↓
StoreProvider.loadStoreItems() called
↓
Query joins StoreItems with ProductInventory:
  - Shows only items where available = true AND (track_inventory = false OR currentStock > 0)
↓
Store items displayed with:
  - Stock status badges
  - Unit descriptions
  - Categories
```

#### 3. Adding Items to Cart
```
Customer clicks on menu item → Meal Detail Screen
↓
Views:
  - Image
  - Description
  - Price
  - Meal weight options
↓
Selects quantity, customizations
↓
Clicks "Add to Cart" → CartProvider.addItem()
↓
CartItem created in memory:
  {
    id: generated,
    menuItemId: UUID,
    mealTitle: "Ugali with Fish",
    price: 300,
    quantity: 2,
    mealImage: URL
  }
↓
Cart saved to SharedPreferences (persists across app restarts)
↓
Cart badge updates (shows total quantity)
↓
Customer repeats for multiple items
```

#### 4. Checkout Process
```
Customer clicks cart icon → Cart Screen
↓
Reviews items:
  - Line items with quantities
  - Can update quantities or remove items
  - Subtotal calculated
↓
Clicks "Proceed to Checkout" → Checkout Screen
↓
Steps:
  A. Select Delivery Address
     - Choose from saved addresses (AddressProvider)
     - Or add new address with GPS coordinates
  
  B. Review Order Summary
     - Subtotal: Sum of item prices
     - Delivery Fee: Calculated based on distance from selected location
     - Tax: Calculated as percentage (from tax_configurations table)
     - Total: Subtotal + Delivery Fee + Tax
  
  C. Choose Payment Method
     - Currently: M-Pesa only
     - Future: Card, Cash on Delivery
↓
Clicks "Pay with M-Pesa"
↓
Phone number input (pre-filled from profile, editable)
↓
Confirmation dialog displays total amount
```

#### 5. Payment Processing (M-Pesa Integration)
```
Customer confirms payment
↓
OrderProvider.createOrder() called:
  1. Insert order into 'orders' table (status: pending_payment)
  2. Insert order_items into 'order_items' table
↓
Order ID returned
↓
MpesaProvider.initiatePayment() called
↓
Flutter app calls Supabase Edge Function: mpesa-stk-push
↓
Edge Function flow:
  1. Formats phone number (254XXXXXXXXX)
  2. Gets M-Pesa access token from Safaricom OAuth
  3. Generates timestamp and password
  4. Posts to Safaricom STK Push API:
     {
       BusinessShortCode: "174379",
       Password: encoded,
       Timestamp: "20231122143522",
       TransactionType: "CustomerPayBillOnline",
       Amount: 950,
       PartyA: "254712345678",
       PartyB: "174379",
       PhoneNumber: "254712345678",
       CallBackURL: "https://.../mpesa-callback",
       AccountReference: "ORD-ABC123",
       TransactionDesc: "Payment for order ORD-ABC123"
     }
  5. Safaricom responds with CheckoutRequestID
  6. Edge function inserts pending transaction:
     INSERT INTO mpesa_transactions (
       checkout_request_id,
       merchant_request_id,
       order_id,
       phone_number,
       amount,
       status,
       user_auth_id
     ) VALUES (..., 'pending', ...);
↓
CheckoutRequestID returned to Flutter app
↓
MpesaProvider starts polling transaction status (every 3 seconds)
↓
Customer receives STK Push on their phone:
  "Enter M-Pesa PIN to pay KES 950 to Ouma's Delicacy"
↓
Customer enters PIN on their phone
↓
Safaricom processes payment...
```

#### 6. Payment Callback and Confirmation
```
Safaricom payment successful
↓
Safaricom posts webhook to: mpesa-callback Edge Function
↓
Callback payload contains:
  - CheckoutRequestID (matches pending transaction)
  - ResultCode (0 = success, >0 = failed)
  - MpesaReceiptNumber (transaction ID)
  - Amount
  - PhoneNumber
  - TransactionDate
↓
Edge Function processes callback:
  1. Finds pending transaction by CheckoutRequestID
  2. Updates mpesa_transactions:
     - status = 'completed'
     - transaction_id = MpesaReceiptNumber
     - transaction_timestamp = TransactionDate
  
  3. If order_id exists in transaction:
     - Updates orders.status = 'confirmed'
  
  4. Generates receipt:
     - Fetches order details with items
     - Calls stored function: generate_receipt_number()
     - Inserts into receipts table:
       {
         receipt_number: "RCP-12345",
         transaction_id: "QGH7XY2Z3M",
         customer_name: "John Doe",
         customer_email: "john@example.com",
         subtotal: 600,
         tax_amount: 96,
         delivery_fee: 200,
         total_amount: 896,
         business_name: "Ouma's Delicacy",
         ...
       }
     - Inserts receipt_items for each order item
  
  5. Email receipt infrastructure:
     - Resend API configured in edge function
     - HTML email template generated
     - Email delivery not yet functional (pending Resend configuration)
↓
Edge Function returns success to Safaricom
↓
Real-time subscription in Flutter app detects:
  - Transaction status change (pending → completed)
  - Order status change (pending_payment → confirmed)
↓
MpesaProvider stops polling, dismisses loading dialog
↓
UI updates:
  - Success message displayed
  - Order appears in "Order History"
  - Receipt available for viewing/download
↓
Cart cleared: CartProvider.clear()
```

#### 7. Order Preparation and Admin Assignment
```
Admin Dashboard receives real-time notification:
  "New Order: ORD-ABC123 (KES 896)"
↓
Admin navigates to Manage Orders Screen
↓
Views order details:
  - Customer name, phone
  - Delivery address
  - Order items with quantities
  - Payment status: PAID
↓
Admin clicks "Start Preparing"
↓
OrderProvider.updateOrderStatus('preparing')
↓
Database update: orders.status = 'preparing'
↓
Real-time subscription → Customer app shows "Order is being prepared"
↓
Admin assigns to rider:
  - Selects available rider from dropdown
  - Clicks "Assign Rider"
↓
Database update:
  - orders.rider_id = '...'
  - orders.status = 'outForDelivery'
↓
Rider app receives real-time notification
```

#### 8. Delivery by Rider
```
Rider Dashboard updates with new delivery
↓
Rider views:
  - Customer name, phone
  - Delivery address with map view (OpenStreetMap)
  - Order items (for verification)
  - Navigation button (opens external map app)
↓
Rider clicks "Navigate" → Opens external map app
↓
Rider delivers order
↓
Rider clicks "Mark as Delivered"
↓
OrderProvider.updateOrderStatus('delivered')
↓
Database updates:
  - orders.status = 'delivered'
  - orders.delivered_at = NOW()
↓
Real-time subscription → Customer app shows:
  "Order Delivered!"
↓
Customer can:
  - View receipt
  - Download/email receipt
  - Rate order items (reviews_provider)
  - Contact support if issues
```

#### 9. Post-Delivery
```
Customer opens Order History
↓
Sees completed order with:
  - Order number
  - Items ordered
  - Total paid
  - Delivery date
  - Receipt number
↓
Clicks "View Receipt" → Receipt displayed with:
  - Business details
  - Customer details
  - Itemized list
  - Tax breakdown
  - M-Pesa transaction ID
↓
Can download PDF or email receipt
↓
Can add items to favorites for quick reorder
↓
Can rate items (1-5 stars) and leave review
```

---

## Payment Integration (M-Pesa)

### STK Push Flow

**Sequence Diagram**:
```
Flutter App → Supabase Edge Function (mpesa-stk-push) → Safaricom API
                                                              ↓
                    ← CheckoutRequestID ← Access Token ← OAuth
                                ↓
                          Database: mpesa_transactions (pending)
                                ↓
                    Customer Phone receives STK Push prompt
                                ↓
                    Customer enters PIN → Safaricom processes
                                ↓
Safaricom → Webhook POST → Edge Function (mpesa-callback)
                                ↓
                          Database Updates:
                            - mpesa_transactions (completed)
                            - orders (confirmed)
                            - receipts (generated)
                                ↓
                          Email Receipt Sent (Resend API)
                                ↓
                    Flutter App ← Real-time update ← Supabase
```

### Transaction States
1. **Pending**: Transaction initiated, awaiting customer input
2. **Completed**: Payment successful, receipt generated
3. **Failed**: Payment declined or timeout

### Error Handling
- **Timeout**: 60 second timeout for STK Push, then marked as failed
- **Declined**: Customer cancels or insufficient funds
- **Network Issues**: Retries with exponential backoff
- **Duplicate Callbacks**: Idempotent processing (checks if already processed)

---

## Security & Offline Capabilities

### Security Measures
1. **Row Level Security (RLS)**: Database policies restrict data access
2. **Authentication**: Supabase Auth with JWT tokens
3. **HTTPS Only**: All API calls encrypted
4. **Environment Variables**: Secrets stored in Supabase, not in code
5. **Rate Limiting**: Password reset cooldown (60s)
6. **Input Validation**: Phone number formatting, email validation

### Offline-First Features
1. **Local Caching**:
   - Cart persisted with SharedPreferences
   - User profile cached
   - Order history cached (24h validity)

2. **Connectivity Detection**:
   - ConnectivityProvider monitors network status
   - Graceful degradation when offline
   - Sync queue for pending operations

3. **Optimistic Updates**:
   - UI updates immediately
   - Background sync when connection restored

4. **Cached Data Display**:
   - Shows cached menu/store items when offline
   - Indicates data staleness with timestamps

---

## Key Technical Decisions

### Why Provider Pattern?
- **Simplicity**: Easy to understand and implement
- **Performance**: Selective rebuilding with notifyListeners()
- **Testability**: Providers can be mocked
- **Flutter Native**: Recommended by Flutter team

### Why Supabase?
- **All-in-One**: Database, Auth, Real-time, Functions
- **PostgreSQL**: Robust relational database
- **Real-time**: WebSocket subscriptions built-in
- **Cost Effective**: Generous free tier

### Why M-Pesa?
- **Market Leader**: 99% of mobile payments in Kenya
- **User Familiarity**: Customers already use M-Pesa
- **No Card Required**: No credit card needed

### Why Edge Functions (Deno)?
- **Serverless**: No server management
- **Secure**: Credentials never exposed to client
- **Scalable**: Automatic scaling by Supabase

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Mobile App                     │
│  (Android, via Flutter Compile)                │
└────────────┬────────────────────────────────────────────┘
             │
             │ HTTPS (Supabase Flutter SDK)
             ↓
┌─────────────────────────────────────────────────────────┐
│                  Supabase Cloud                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  PostgreSQL Database (with RLS & Triggers)      │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Supabase Auth (JWT-based authentication)      │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Supabase Realtime (WebSocket subscriptions)   │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Edge Functions (Deno serverless):             │   │
│  │    - mpesa-stk-push                             │   │
│  │    - mpesa-callback                             │   │
│  └─────────────────────────────────────────────────┘   │
└───────┬────────────────────────────────────┬────────────┘
        │                                    │
        │ HTTPS                              │ HTTPS (Webhook)
        ↓                                    ↓
┌──────────────────┐              ┌──────────────────────┐
│ Safaricom Daraja │              │    Resend API        │
│  (M-Pesa API)    │              │  (Email Delivery)    │
└──────────────────┘              └──────────────────────┘
```

---

## Performance Optimizations

1. **Lazy Loading**: Menu items loaded on demand by category
2. **Image Caching**: Network images cached locally
3. **Debounced Search**: Search queries debounced (300ms)
4. **Pagination**: Order history paginated (20 per page)
5. **Batch Operations**: Multiple inventory updates batched
6. **Index Optimization**: Database indexes on frequently queried columns

---

## Future Enhancements

1. **Email Receipt Delivery**: Complete Resend API integration for automatic email receipts
2. **Multi-Location Support**: Expand to multiple restaurant/store locations with zone management
3. **iOS and Web Deployment**: Build and deploy for iOS App Store and web browsers
4. **Loyalty Program**: Points system for frequent customers
5. **Push Notifications**: Firebase Cloud Messaging for order updates
6. **Analytics Dashboard**: Advanced reporting with Grafana/Metabase
7. **AI Recommendations**: ML-based product suggestions based on order history
8. **Table Reservations**: Dine-in booking system
9. **Promo Codes**: Discount coupon and promotional campaign management
10. **Split Payments**: Multiple payment methods per order (M-Pesa + Card)
11. **Google Maps Integration**: Replace OpenStreetMap with Google Maps for better navigation

---

## Monitoring and Logging

### Logging Strategy
- **Flutter**: debugPrint() statements with emojis for visibility (🔄 loading, ✅ success, ❌ error)
- **Edge Functions**: console.log() with structured JSON
- **Supabase Dashboard**: Real-time function logs and database queries

### Metrics Tracked
- Order volume by hour/day
- Payment success rate
- Average order value
- Delivery time (order → delivered)
- Customer satisfaction (ratings)
- Inventory turnover rate

---

## Conclusion

The Ouma's Delicacy system is a production-ready food ordering platform for Android with:
- **Clean architecture** separating concerns (models, services, providers, UI)
- **Real-time capabilities** via Supabase subscriptions for live order tracking
- **Secure payment integration** with M-Pesa STK Push for mobile money
- **Offline-first design** with local caching for reliable user experience
- **Multi-role support** (admin, customer, rider) with role-based access control
- **Inventory management** with real-time stock tracking and low stock alerts
- **Automated receipt generation** stored in database (email delivery pending)
- **UUID-based data model** for security and distributed system compatibility
- **Terms & Conditions** acceptance during registration for legal compliance
- **OpenStreetMap integration** for address selection and map display
- **Single location system** (multi-location support planned for future)

The system demonstrates best practices in Flutter development, state management with Provider pattern, Supabase backend integration, and mobile payment processing with M-Pesa.

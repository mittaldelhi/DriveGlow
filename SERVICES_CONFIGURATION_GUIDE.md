# Services & Subscriptions Configuration Guide

## Overview

DriveGlow now has a unified service system that supports:
- ✅ **One-Time Services** - Individual bookings
- ✅ **Monthly Subscriptions** - Recurring monthly plans
- ✅ **Yearly Subscriptions** - Recurring yearly plans
- ✅ **Fully Customizable** - All managed via Admin Panel

---

## Database Schema

### 1. Service Pricing Table (`service_pricing`)

This is the **main table** for managing all services and subscription offerings.

#### Fields:
```sql
CREATE TABLE service_pricing (
  id UUID PRIMARY KEY,
  category TEXT,                    -- e.g., 'Car Wash', 'Detailing', 'Maintenance'
  service_name TEXT,                -- e.g., 'Exterior Wash', 'Premium Package'
  tier TEXT,                        -- e.g., 'SEDAN (A)', 'SUV (B)', 'LUX (C)'
  plan_type TEXT,                   -- 'One-Time', 'Monthly', 'Yearly'
  price DECIMAL,                    -- Price in dollars
  is_active BOOLEAN DEFAULT true,   -- Show/hide service
  is_special BOOLEAN DEFAULT false, -- Mark as premium/special service
  is_subscription_eligible BOOLEAN DEFAULT true, -- Can be auto-renewed
  subtitle TEXT,                    -- Optional subtitle (e.g., "Save $41/yr")
  display_order INTEGER DEFAULT 0,  -- Sort order
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

#### Example Data:

**One-Time Services:**
```json
{
  "service_name": "Basic Exterior Wash",
  "category": "Car Wash",
  "tier": "SEDAN (A)",
  "plan_type": "One-Time",
  "price": 25.00,
  "is_active": true,
  "display_order": 1
}
```

**Monthly Subscription Plans:**
```json
{
  "service_name": "Monthly Wash Plan",
  "category": "Car Wash",
  "tier": "SEDAN (A)",
  "plan_type": "Monthly",
  "price": 49.99,
  "is_active": true,
  "display_order": 1,
  "subtitle": "2 Washes/Month"
}
```

**Yearly Subscription Plans:**
```json
{
  "service_name": "Annual Wash Package",
  "category": "Car Wash",
  "tier": "SEDAN (A)",
  "plan_type": "Yearly",
  "price": 499.99,
  "is_active": true,
  "display_order": 1,
  "subtitle": "Save $99/yr"
}
```

---

## App Structure

### File Organization

```
lib/
├── domain/
│   └── models/
│       ├── service_pricing_model.dart      ← Core pricing model
│       └── standard_service_model.dart     ← Standard services
│
├── infrastructure/
│   └── repositories/
│       ├── admin_ops_repository.dart       ← Service fetching logic
│       └── standard_service_repository.dart
│
├── application/
│   └── providers/
│       ├── feature_providers.dart          ← Service providers
│       └── standard_service_providers.dart
│
└── presentation/
    ├── booking/
    │   └── service_selection_screen.dart   ← NEW: Unified booking screen
    └── services/
        ├── standard_care_screen.dart       ← View all standard services
        └── subscription_screen.dart        ← View all subscription plans
```

### Data Flow

```
Admin Panel (Edit Services)
    ↓
Supabase service_pricing table
    ↓
AdminOpsRepository
    ├─ getOneTimeServices()
    ├─ getSubscriptionServices('Monthly')
    └─ getSubscriptionServices('Yearly')
    ↓
Feature Providers
    ├─ oneTimeServicesProvider
    ├─ monthlySubscriptionPlansProvider
    └─ yearlySubscriptionPlansProvider
    ↓
ServiceSelectionScreen
    ├─ One Time Tab    → Shows all one-time services
    └─ Subscription Tab
        ├─ Monthly    → Shows all monthly plans
        └─ Yearly     → Shows all yearly plans
    ↓
Payment Screen → Create Booking
```

---

## Usage

### For Admin - Managing Services

#### Add a One-Time Service:
```json
{
  "service_name": "Full Interior Detail",
  "category": "Detailing",
  "tier": "SUV (B)",
  "plan_type": "One-Time",
  "price": 159.99,
  "is_active": true,
  "is_special": false,
  "display_order": 2
}
```

#### Add a Monthly Subscription Plan:
```json
{
  "service_name": "Premium Monthly",
  "category": "Car Wash",
  "tier": "SEDAN (A)",
  "plan_type": "Monthly",
  "price": 79.99,
  "is_active": true,
  "subtitle": "Unlimited washes + 10% accessories discount",
  "display_order": 2
}
```

#### Add a Yearly Subscription Plan:
```json
{
  "service_name": "Elite Annual Protection",
  "category": "Detailing",
  "tier": "LUX (C)",
  "plan_type": "Yearly",
  "price": 1299.99,
  "is_active": true,
  "is_special": true,
  "subtitle": "Save $199/yr",
  "display_order": 1
}
```

### For Users - Booking a Service

**Flow:**
1. User taps "Book Now" from dashboard
2. Opens `ServiceSelectionScreen`
3. **One-Time Tab:**
   - Shows all services with `plan_type = "One-Time"`
   - Displays by category and tier
   - Tap "Book Now" → Payment Screen
4. **Subscription Tab:**
   - Select Monthly or Yearly
   - Shows plans with matching `plan_type`
   - Tap "Subscribe Now" → Payment Screen

---

## Repository Methods

### AdminOpsRepository

```dart
// Get one-time services only
Future<List<ServicePricingModel>> getOneTimeServices(){
  // Returns: plan_type == "One-Time" && is_active == true
}

// Get subscription services by duration
Future<List<ServicePricingModel>> getSubscriptionServices(String duration){
  // duration: 'Monthly' or 'Yearly'
  // Returns: plan_type == duration && is_active == true
}

// Get all pricing for category (legacy, still available)
Future<List<ServicePricingModel>> getServicePricing(String category){
  // Returns all services in category
}

// Update pricing batch
Future<void> updatePricingBatch(List<ServicePricingModel> pricingList){
  // Update multiple services at once
}
```

---

## Service Pricing Model

```dart
class ServicePricingModel {
  final String id;
  final String category;           // e.g., 'Car Wash'
  final String serviceName;        // e.g., 'Exterior Wash'
  final String tier;               // e.g., 'SEDAN (A)', 'SUV (B)'
  final String planType;           // 'One-Time', 'Monthly', 'Yearly'
  final double price;
  final bool isActive;
  final bool isSpecial;            // Premium badge
  final bool isSubscriptionEligible; // Auto-renewal eligible
  final String? subtitle;          // Optional (e.g., "Save $41/yr")
}
```

---

## Key Features

### ✅ One-Time Services
- Show in "Book Now" when any service is selected
- Display with pricing per service
- No subscription commitment

### ✅ Monthly Subscriptions
- Recurring monthly billing
- Show frequency info (e.g., "2 Washes/Month")
- Can include discounts

### ✅ Yearly Subscriptions
- Recurring yearly billing
- Show savings vs. monthly
- Better pricing incentive

### ✅ Admin Customization
- Add/Edit/Delete services
- Change prices anytime
- Activate/Deactivate services
- Set display order
- Add special badges
- Add descriptive subtitles

### ✅ Flexible Tiers
- SEDAN (A) - Standard vehicles
- SUV (B) - Larger vehicles
- LUX (C) - Premium vehicles
- Custom tiers as needed

---

## Provider Configuration

### In `feature_providers.dart`:

```dart
// One-Time Services
final oneTimeServicesProvider = FutureProvider<List<ServicePricingModel>>((
  ref,
) async {
  return ref.read(adminOpsRepositoryProvider).getOneTimeServices();
});

// Monthly Subscriptions
final monthlySubscriptionPlansProvider =
    FutureProvider<List<ServicePricingModel>>((ref) async {
      return ref.read(adminOpsRepositoryProvider)
          .getSubscriptionServices('Monthly');
    });

// Yearly Subscriptions
final yearlySubscriptionPlansProvider =
    FutureProvider<List<ServicePricingModel>>((ref) async {
      return ref.read(adminOpsRepositoryProvider)
          .getSubscriptionServices('Yearly');
    });

// Dynamic duration
final subscriptionServicesByDurationProvider =
    FutureProvider.family<List<ServicePricingModel>, String>((
      ref,
      duration,
    ) async {
      return ref.read(adminOpsRepositoryProvider)
          .getSubscriptionServices(duration);
    });
```

---

## Usage in ServiceSelectionScreen

```dart
// Load one-time services
final servicesAsync = ref.watch(oneTimeServicesProvider);

// Load subscription plans
final plansAsync = ref.watch(
  subscriptionServicesByDurationProvider(_subscriptionDuration)
);

// Switch based on user selection
_selectedTabIndex == 0 
  ? _buildOneTimeServices()  // Shows all one-time
  : _buildSubscriptionServices() // Shows monthly or yearly
```

---

## Admin Panel Tasks (To be implemented)

Create screens in `/presentation/admin/` for:

1. **Service Management** (`admin_services_screen.dart`)
   - List all services with filters by type
   - Add new service pricing
   - Edit existing service
   - Toggle active status
   - Set display order

2. **Subscription Plans** (`admin_subscription_management.dart`)
   - List all subscription plans
   - Create monthly/yearly plans
   - Bulk pricing updates
   - Feature/benefit management

3. **Pricing Dashboard** (`admin_pricing_dashboard.dart`)
   - Analytics on service popularity
   - Revenue by service type
   - Subscription conversion rates

---

## Migration Notes

If you had old `service_pricing` structure:
- Ensure `plan_type` field exists
- Set `is_active = true` for live services
- Set proper `display_order`
- Add `is_special` for premium services
- Keep `is_subscription_eligible = true` for recurring

---

## Quick Reference

### Display All One-Time Services
```dart
ref.watch(oneTimeServicesProvider)
```

### Display Monthly Plans
```dart
ref.watch(monthlySubscriptionPlansProvider)
```

### Display Yearly Plans
```dart
ref.watch(yearlySubscriptionPlansProvider)
```

### Display by Duration (Dynamic)
```dart
ref.watch(subscriptionServicesByDurationProvider('Monthly'))
ref.watch(subscriptionServicesByDurationProvider('Yearly'))
```

---

## Testing Checklist

- [ ] One-Time tab shows all one-time services
- [ ] Subscription tab shows monthly plans first
- [ ] Monthly/Yearly toggle works
- [ ] Prices display correctly
- [ ] "Book Now" and "Subscribe Now" buttons work
- [ ] Navigation to payment works with correct data
- [ ] Services can be activated/deactivated via admin
- [ ] Display order affects sorting
- [ ] Special badge shows for premium services
- [ ] Subtitle displays correctly on relevant services

# 🚀 IMPLEMENTATION GUIDE - COMPLETE BOOKING FLOW

**Last Updated:** February 22, 2026  
**Phase:** 3/5 - Customer UI Implementation

---

## ✅ STATUS CHECKLIST

### **COMPLETED ✅**

- [x] Database schema (3 tables: subscription_plans, service_pricing, standard_services)
- [x] Admin dashboard (Subscriptions tab, One-Time Services tab)
- [x] Real-time streaming (StreamProviders with live updates)
- [x] 18 subscription plans seeded (Silver/Gold/Platinum × Monthly/Yearly)
- [x] 15 one-time services seeded (Various categories)
- [x] Admin CRUD operations (Add, Edit, Delete, Toggle ON/OFF)
- [x] Error handling with user-friendly messages
- [x] Repository pattern with Supabase integration
- [x] Service ecosystem blueprint (documentation)
- [x] NEW: Customer Services screen (customer_services_screen.dart)

### **IN PROGRESS 🔄**

- [ ] Update routing to use customer_services_screen
- [ ] Create booking details screen
- [ ] Create booking confirmation flow
- [ ] Create payment integration layer
- [ ] Test end-to-end flow

### **PENDING ⏳**

- [ ] Order history screen
- [ ] Active subscriptions screen
- [ ] Payment gateway setup (Razorpay/Stripe)
- [ ] Email notifications
- [ ] Analytics dashboard
- [ ] Push notifications

---

## 📁 FILE STRUCTURE (New Files Created)

```
lib/
├── presentation/
│   ├── services/
│   │   ├── services_screen.dart (EXISTING - Main hub)
│   │   └── customer_services_screen.dart ⭐ NEW
│   │
│   ├── booking/
│   │   ├── service_selection_screen.dart (UPDATE NEEDED)
│   │   ├── booking_details_screen.dart (CREATE)
│   │   ├── booking_confirmation_screen.dart (CREATE)
│   │   └── payment_screen.dart (CREATE)
│   │
│   ├── customer/
│   │   ├── order_history_screen.dart (CREATE)
│   │   ├── active_subscriptions_screen.dart (CREATE)
│   │   └── add_ons_screen.dart (CREATE)
│   │
│   └── admin/
│       └── screens/
│           ├── admin_subscription_management.dart ✅
│           ├── admin_standard_services_screen.dart ✅
│           └── admin_service_pricing_management.dart (UPDATE NEEDED)
│
├── domain/
│   ├── models/
│   │   └── booking_model.dart (CREATE)
│   │
│   └── repositories/
│       └── booking_repository.dart (CREATE)
│
├── infrastructure/
│   ├── supabase/
│   │   └── supabase_client.dart ✅
│   │
│   └── migrations/
│       └── (Already updated)
│
└── application/
    ├── providers/
    │   ├── feature_providers.dart ✅ (Has oneTimeServicesProvider)
    │   └── booking_providers.dart (CREATE)
    │
    └── notifiers/
        └── booking_notifier.dart (CREATE)
```

---

## 🔄 STEP-BY-STEP IMPLEMENTATION

### **PHASE 3.1: Update Routing**

**File:** `lib/main.dart`

```dart
// BEFORE:
// '/services' routes to OurServicesScreen with categories

// AFTER:
route.go('/services', (state) => const CustomerServicesScreen());

// Also add routes:
route.go('/booking/details', (state) => const BookingDetailsScreen());
route.go('/booking/confirmation', (state) => const BookingConfirmationScreen());
route.go('/booking/payment', (state) => const BookingPaymentScreen());
```

---

### **PHASE 3.2: Create Booking Data Models**

**File:** `lib/domain/models/booking_model.dart` (CREATE)

```dart
class BookingModel {
  final String? id;
  final String customerId;
  final String serviceId;  // From service_pricing
  final DateTime bookedDate;
  final TimeOfDay? timeSlot;
  final String status; // pending, confirmed, completed
  final double totalAmount;
  final String paymentStatus; // pending, paid, failed
  final Map<String, dynamic>? specialRequests;
  final String? notes;
  final DateTime createdAt;

  BookingModel({
    this.id,
    required this.customerId,
    required this.serviceId,
    required this.bookedDate,
    this.timeSlot,
    this.status = 'pending',
    required this.totalAmount,
    this.paymentStatus = 'pending',
    this.specialRequests,
    this.notes,
    required this.createdAt,
  });

  // copyWith, toMap, fromMap methods...
}

// For subscriptions with add-ons:
class SubscriptionBookingModel {
  final String? id;
  final String customerId;
  final String subscriptionPlanId;
  final List<String> addOnServiceIds;  // Optional one-time services added
  final DateTime startDate;
  final DateTime? autoRenewalDate;
  final String status; // active, paused, cancelled
  final double planAmount;
  final double addOnsAmount;
  final double totalAmount;
  final String paymentStatus;
  final String billingCycle; // monthly, yearly
  final DateTime createdAt;

  SubscriptionBookingModel({
    this.id,
    required this.customerId,
    required this.subscriptionPlanId,
    this.addOnServiceIds = const [],
    required this.startDate,
    this.autoRenewalDate,
    this.status = 'active',
    required this.planAmount,
    this.addOnsAmount = 0,
    required this.totalAmount,
    this.paymentStatus = 'pending',
    required this.billingCycle,
    required this.createdAt,
  });
}
```

---

### **PHASE 3.3: Create Booking Repository**

**File:** `lib/domain/repositories/booking_repository.dart` (CREATE)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final SupabaseClient supabase;

  BookingRepository(this.supabase);

  // CRUD Operations
  
  /// Create a new one-time service booking
  Future<String> createBooking(BookingModel booking) async {
    try {
      final response = await supabase.from('bookings').insert({
        'customer_id': booking.customerId,
        'service_id': booking.serviceId,
        'booked_date': booking.bookedDate.toIso8601String(),
        'time_slot': booking.timeSlot != null
            ? '${booking.timeSlot!.hour}:${booking.timeSlot!.minute}'
            : null,
        'status': booking.status,
        'total_amount': booking.totalAmount,
        'payment_status': booking.paymentStatus,
        'special_requests': booking.specialRequests,
        'notes': booking.notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id');

      return response[0]['id'];
    } catch (e) {
      throw Exception('❌ Failed to create booking: $e');
    }
  }

  /// Get user's booking history
  Future<List<BookingModel>> getUserBookings(String customerId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => BookingModel.fromMap(json))
          .toList();
    } catch (e) {
      throw Exception('❌ Failed to fetch bookings: $e');
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await supabase
          .from('bookings')
          .update({'status': status}).eq('id', bookingId);
    } catch (e) {
      throw Exception('❌ Failed to update booking: $e');
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus(String bookingId, String paymentStatus) async {
    try {
      await supabase
          .from('bookings')
          .update({'payment_status': paymentStatus}).eq('id', bookingId);
    } catch (e) {
      throw Exception('❌ Failed to update payment: $e');
    }
  }

  /// Stream bookings for real-time updates
  Stream<List<BookingModel>> streamUserBookings(String customerId) {
    return supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .map((event) =>
            (event as List).map((json) => BookingModel.fromMap(json)).toList())
        .handleError((err) {
          throw Exception('❌ Stream error: $err');
        });
  }
}
```

---

### **PHASE 3.4: Create Booking Providers**

**File:** `lib/application/providers/booking_providers.dart` (CREATE)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/repositories/booking_repository.dart';
import './repositories_provider.dart';

// Booking repository provider
final bookingRepositoryProvider = Provider((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});

// User's booking history (stream)
final userBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, customerId) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.streamUserBookings(customerId);
});

// Create booking state notifier
class BookingNotifier extends StateNotifier<AsyncValue<String>> {
  final BookingRepository _repository;

  BookingNotifier(this._repository) : super(const AsyncValue.data(''));

  Future<void> createBooking(BookingModel booking) async {
    state = const AsyncValue.loading();
    try {
      final bookingId = await _repository.createBooking(booking);
      state = AsyncValue.data(bookingId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Booking creation provider
final bookingNotifierProvider =
    StateNotifierProvider<BookingNotifier, AsyncValue<String>>((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return BookingNotifier(repo);
});
```

---

### **PHASE 3.5: Create Booking Details Screen**

**File:** `lib/presentation/booking/booking_details_screen.dart` (CREATE)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/service_pricing_model.dart';
import '../../../theme/app_theme.dart';

/// Booking Details Screen
/// User selects date, time, and special requests
class BookingDetailsScreen extends ConsumerStatefulWidget {
  final ServicePricingModel service;

  const BookingDetailsScreen({
    super.key,
    required this.service,
  });

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _specialRequestsController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Service Summary
          SliverToBoxAdapter(
            child: _buildServiceSummary(),
          ),

          // Date Selection
          SliverToBoxAdapter(
            child: _buildDateSelector(),
          ),

          // Time Selection
          SliverToBoxAdapter(
            child: _buildTimeSelector(),
          ),

          // Special Requests
          SliverToBoxAdapter(
            child: _buildSpecialRequests(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Total & Book Button
          SliverToBoxAdapter(
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummary() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: Icon(
                Icons.local_car_wash_rounded,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.service.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.service.price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF0541E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickDate(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDate != null
                      ? const Color(0xFFF0541E)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFFF0541E)),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate == null
                        ? 'Choose a date'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedDate == null ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Time',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _selectedDate == null ? null : () => _pickTime(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedTime != null
                      ? const Color(0xFFF0541E)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Color(0xFFF0541E)),
                  const SizedBox(width: 12),
                  Text(
                    _selectedTime == null
                        ? 'Choose a time'
                        : _selectedTime!.format(context),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedTime == null ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDate == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '(Select date first)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialRequests() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Special Requests (Optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialRequestsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add any special requests or notes...',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF0541E),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isComplete =
        _selectedDate != null && _selectedTime != null;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Service',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '₹${widget.service.price.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '₹${widget.service.price.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF0541E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Proceed button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isComplete ? () => _proceedToConfirmation() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0541E),
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CONFIRM & REVIEW',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isComplete ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _proceedToConfirmation() {
    Navigator.pushNamed(
      context,
      '/booking/confirmation',
      arguments: {
        'service': widget.service,
        'date': _selectedDate,
        'time': _selectedTime,
        'specialRequests': _specialRequestsController.text,
      },
    );
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }
}
```

---

## 💾 DATABASE MIGRATION: BOOKINGS TABLE

**File:** `supabase/migrations/20250222_create_bookings_table.sql`

```sql
-- Create bookings table for tracking one-time service bookings
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES service_pricing(id) ON DELETE RESTRICT,
  booked_date TIMESTAMP NOT NULL,
  time_slot VARCHAR(10),
  status VARCHAR(20) DEFAULT 'pending',
  total_amount DECIMAL(10, 2) NOT NULL,
  payment_status VARCHAR(20) DEFAULT 'pending',
  special_requests JSONB,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX idx_bookings_service_id ON bookings(service_id);
CREATE INDEX idx_bookings_booked_date ON bookings(booked_date);
CREATE INDEX idx_bookings_status ON bookings(status);

-- RLS Policies
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Customers can view their own bookings
CREATE POLICY "Users can view their bookings"
  ON bookings FOR SELECT
  USING (auth.uid() = customer_id);

-- Customers can create bookings
CREATE POLICY "Users can create bookings"
  ON bookings FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

-- Customers can update their bookings
CREATE POLICY "Users can update their bookings"
  ON bookings FOR UPDATE
  USING (auth.uid() = customer_id);

-- Admin can view all bookings
CREATE POLICY "Admin can view all bookings"
  ON bookings FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ));

-- Admin can update bookings
CREATE POLICY "Admin can update all bookings"
  ON bookings FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ));
```

---

## 🎯 NEXT IMPLEMENTATION STEPS

### **Step 1: Update Database** (5 minutes)
1. Go to Supabase SQL Editor
2. Paste migration SQL for bookings table
3. Run query
4. Verify table created

### **Step 2: Update Routing** (10 minutes)
1. Update `lib/main.dart`
2. Add routes for booking screens
3. Update navigation from customer_services_screen

### **Step 3: Implement Booking Models** (15 minutes)
1. Create `booking_model.dart`
2. Create `booking_repository.dart`
3. Add serialization (toMap, fromMap)

### **Step 4: Create Booking Providers** (10 minutes)
1. Create `booking_providers.dart`
2. Add StreamProvider for realtime booking updates
3. Add StateNotifier for booking creation

### **Step 5: Implement Booking Screens** (45 minutes)
1. Make customer_services_screen send to booking flow
2. Create `booking_details_screen.dart`
3. Create `booking_confirmation_screen.dart`
4. Create `payment_screen.dart`

### **Step 6: Test & Debug** (30 minutes)
1. End-to-end flow test
2. Error handling
3. Real-time updates on admin

### **Step 7: Payment Integration** (∞ hours)
1. Razorpay or Stripe setup
2. Payment processing
3. Webhook handling

---

## 🧪 TESTING CHECKLIST

- [ ] Customer can browse one-time services
- [ ] Customer can filter services by category
- [ ] Customer can click "Book Now"
- [ ] Date picker works
- [ ] Time picker works
- [ ] Special requests text field works
- [ ] Can proceed to confirmation
- [ ] Booking appears in order history
- [ ] Admin can see booking in dashboard
- [ ] Real-time updates when booking status changes
- [ ] Error handling for invalid dates

---

## ⚡ KEY PATTERNS & CONVENTIONS

### **Realtime Pattern**
```dart
// ✅ For live updates, use StreamProvider with invalidation
final userBookingsProvider = StreamProvider.family<List<BookingModel>, String>(...);

// ✅ After creating booking, invalidate stream
void _createBooking() async {
  await bookingRepo.createBooking(booking);
  ref.invalidate(userBookingsProvider);  // ← Force stream refresh
}
```

### **Error Handling Pattern**
```dart
// ✅ Try-catch at repository level
try {
  // Database operation
} catch (e) {
  throw Exception('❌ Operation failed: $e');
}

// ✅ In UI, show user-friendly message
asyncData.when(
  error: (err, stack) => Text('Unable to load bookings'),
);
```

### **Navigation Pattern**
```dart
// ✅ Pass data via arguments
Navigator.pushNamed(
  context,
  '/booking/details',
  arguments: service,
);

// ✅ Receive in destination
widget.service as ServicePricingModel
```

---

## 📞 COMPLETION STATUS

**This Setup = 60% of Complete Booking Flow**

Completion breakdown:
- ✅ 30% - Schema & database (DONE)
- ✅ 20% - Admin management (DONE)
- 🔄 10% - Customer services UI (IN PROGRESS)
- ⏳ 20% - Booking flow screens (NEXT)
- ⏳ 20% - Payment integration (FINAL)

**Estimated time to core functionality: 3-4 hours**

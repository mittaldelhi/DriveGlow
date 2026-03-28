import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/profile_providers.dart';
import '../../application/helpers/booking_validation_helper.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/models/coupon_model.dart';
import '../../domain/models/vehicle_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/time_slot_picker.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'apple_pay';
  late TextEditingController _couponController;
  CouponModel? _appliedCoupon;
  double _discountAmount = 0.0;
  String _couponErrorMessage = '';
  bool _couponLoading = false;

  bool _isService = false;
  String _itemName = 'Yearly Subscription';
  String _itemLabel = 'SELECTED PLAN';
  double _basePrice = 1200.0;
  String _itemDescription = 'Valid for 365 days';
  String _itemId = '';
  bool _fromSubscriptionBooking = false;
  String _subscriptionPlanId = '';
  String _subscriptionDuration = '';
  String _autoCouponName = '';
  List<VehicleModel> _vehicles = const [];
  String? _selectedVehicleId;
  final Set<String> _selectedVehicleIds = {};
  String? _selectedTimeSlot; // NEW: For time slot selection

  final Map<String, bool?> _vehicleHasSubscription = {};
  final Map<String, double> _vehicleSubscriptionPrice = {};
  bool _isLoadingVehicleStatus = false;
  String _preselectedVehicleNumber = '';
  bool _blockedDueToExistingSubscription = false;
  String _blockedVehicleMessage = '';

  final List<CouponModel> _availableCoupons = [];

  // Time slots: 9:00 AM to 7:30 PM (30-min intervals)
  static const List<String> timeSlots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '01:00 PM',
    '01:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM',
    '06:00 PM',
    '06:30 PM',
    '07:00 PM',
    '07:30 PM',
  ];

  bool get _isCouponLocked => _fromSubscriptionBooking;

  int get _vehicleCountForBilling {
    if (_isService) return 1;
    return _selectedVehicleIds.isEmpty ? 1 : _selectedVehicleIds.length;
  }

  double get _subtotal {
    if (_isService && _selectedVehicleId != null) {
      if (_fromSubscriptionBooking) {
        return 0.0;
      }
      return _basePrice;
    } else if (!_isService) {
      double total = 0;
      for (final vehicleId in _selectedVehicleIds) {
        if (_fromSubscriptionBooking) {
          total += 0.0;
        } else {
          total += _basePrice;
        }
      }
      return total;
    }
    return _basePrice;
  }

  double get _effectiveDiscount {
    if (_fromSubscriptionBooking) return _subtotal;
    return _discountAmount.clamp(0, _subtotal);
  }

  double get _total =>
      (_subtotal - _effectiveDiscount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _couponController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        setState(() {
          _isService = args['isService'] as bool? ?? false;
          _fromSubscriptionBooking =
              args['fromSubscriptionBooking'] as bool? ?? false;
          _subscriptionPlanId = args['subscriptionPlanId'] as String? ?? '';
          _autoCouponName = args['autoCouponName'] as String? ?? '';

          if (_isService) {
            _itemLabel = 'SELECTED SERVICE';
            _itemId = args['serviceId'] as String? ?? '';
            _itemName = args['serviceName'] as String? ?? 'Service';
            _itemDescription = args['serviceDescription'] as String? ?? '';
            _basePrice = (args['servicePrice'] as num?)?.toDouble() ?? 0.0;
          } else {
            _itemLabel = 'SELECTED PLAN';
            _itemId = args['planId'] as String? ?? '';
            _itemName = args['planName'] as String? ?? 'Yearly Subscription';
            _subscriptionDuration = args['duration'] as String? ?? '';
            _itemDescription = _subscriptionDuration.isNotEmpty
                ? 'Billing: $_subscriptionDuration'
                : 'Valid for ${args['duration'] as String? ?? '365'} days';
            _basePrice = (args['price'] as num?)?.toDouble() ?? 1200.0;
          }

          if (_fromSubscriptionBooking) {
            _autoCouponName = _autoCouponName.isNotEmpty
                ? _autoCouponName
                : 'Subscription';
            _discountAmount = _subtotal;
            _preselectedVehicleNumber =
                args['selectedVehicleNumber'] as String? ?? '';
          }

          final preselectedVehicleId = args['selectedVehicleId'] as String?;
          final preselectedVehicleNumber =
              args['selectedVehicleNumber'] as String?;
          if (!_isService &&
              preselectedVehicleId != null &&
              preselectedVehicleNumber != null) {
            _selectedVehicleId = preselectedVehicleId;
            _preselectedVehicleNumber = preselectedVehicleNumber;
          }
        });
      }
      await _loadVehicles();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingVehicleStatus = false);
      return;
    }

    setState(() => _isLoadingVehicleStatus = true);

    try {
      print('[VEHICLES] Loading profile for user: ${user.id}');
      final profile = await ref
          .read(userRepositoryProvider)
          .getProfile(user.id)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('[VEHICLES] Profile loading timed out');
              return null;
            },
          );
      final vehicles = profile?.vehicles ?? <VehicleModel>[];
      print('[VEHICLES] Got ${vehicles.length} vehicles');

      if (!mounted) return;

      if (vehicles.isEmpty) {
        setState(() {
          _vehicles = [];
          _vehicleHasSubscription.clear();
          _isLoadingVehicleStatus = false;
          _blockedDueToExistingSubscription = false;
          _blockedVehicleMessage = '';
        });
        return;
      }

      final isNewSubscriptionPurchase =
          !_isService && !_fromSubscriptionBooking;
      // Use bool? to support: true=has subscription, false=no subscription, null=unknown (loading/error)
      final Map<String, bool?> vehicleSubStatus = {};
      bool hasUnknownStatus = false;

      // Check subscription status for all vehicles with timeout
      for (final vehicle in vehicles) {
        bool? hasSub;
        try {
          print(
            '[VEHICLES] Checking subscription for: ${vehicle.licensePlate}',
          );
          // Use Future.any pattern to handle timeout properly
          hasSub = await Future.any([
            BookingValidationHelper.hasActiveSubscription(
              userId: user.id,
              vehicleNumber: vehicle.licensePlate,
            ),
            Future.delayed(const Duration(seconds: 10), () => null as bool?),
          ]);
          vehicleSubStatus[vehicle.id] = hasSub;
          if (hasSub == null) hasUnknownStatus = true;
          print('[VEHICLES] ${vehicle.licensePlate} has subscription: $hasSub');
        } catch (e) {
          print(
            '[VEHICLES] Subscription check error for ${vehicle.licensePlate}: $e',
          );
          vehicleSubStatus[vehicle.id] = null; // Return null for unknown status
          hasUnknownStatus = true;
        }
      }

      if (!mounted) return;

      List<VehicleModel> displayVehicles;

      if (isNewSubscriptionPurchase) {
        // Check if any vehicle has unknown status - block purchase until confirmed
        if (hasUnknownStatus) {
          setState(() {
            _vehicles = [];
            _vehicleHasSubscription.clear();
            _vehicleHasSubscription.addAll(vehicleSubStatus);
            _selectedVehicleId = null;
            _selectedVehicleIds.clear();
            _isLoadingVehicleStatus = false;
            _blockedDueToExistingSubscription = true;
            _blockedVehicleMessage =
                'Verifying subscription status... Please try again.';
          });
          return;
        }

        // For NEW subscription purchase: show ONLY vehicles WITHOUT active subscription
        // Only include vehicles where status is explicitly FALSE (no subscription)
        displayVehicles = vehicles
            .where((v) => vehicleSubStatus[v.id] == false)
            .toList();

        if (displayVehicles.isEmpty) {
          // All vehicles have subscription - show empty state with block message
          setState(() {
            _vehicles = [];
            _vehicleHasSubscription.clear();
            _vehicleHasSubscription.addAll(vehicleSubStatus);
            _selectedVehicleId = null;
            _selectedVehicleIds.clear();
            _isLoadingVehicleStatus = false;
            _blockedDueToExistingSubscription = true;
            _blockedVehicleMessage =
                'All your vehicles have active subscriptions';
          });
          return;
        }
      } else {
        // For standard services or from existing subscription: show ALL vehicles
        displayVehicles = vehicles;
      }

      // Select default vehicle
      VehicleModel? vehicleToSelect;
      if (_preselectedVehicleNumber.isNotEmpty) {
        try {
          vehicleToSelect = displayVehicles.firstWhere(
            (v) =>
                v.licensePlate.toUpperCase() ==
                _preselectedVehicleNumber.toUpperCase(),
          );
        } catch (e) {
          // Not found in displayVehicles, try in all vehicles
          try {
            vehicleToSelect = vehicles.firstWhere(
              (v) =>
                  v.licensePlate.toUpperCase() ==
                  _preselectedVehicleNumber.toUpperCase(),
            );
          } catch (_) {}
        }
      }
      vehicleToSelect ??= displayVehicles.isNotEmpty
          ? displayVehicles.firstWhere(
              (v) => v.isPrimary,
              orElse: () => displayVehicles.first,
            )
          : null;

      // For new subscription purchase, ensure selected vehicle doesn't have subscription
      if (isNewSubscriptionPurchase && vehicleToSelect != null) {
        final hasSub = vehicleSubStatus[vehicleToSelect.id] ?? false;
        if (hasSub) {
          // Find first vehicle without subscription
          vehicleToSelect = displayVehicles
              .where((v) => !(vehicleSubStatus[v.id] ?? false))
              .firstOrNull;
        }
      }

      if (!mounted) return;

      print('[VEHICLES] Setting state with ${displayVehicles.length} vehicles');
      setState(() {
        _vehicles = displayVehicles;
        _vehicleHasSubscription.clear();
        _vehicleHasSubscription.addAll(vehicleSubStatus);

        if (vehicleToSelect != null) {
          _selectedVehicleId = vehicleToSelect.id;
          _selectedVehicleIds.clear();
          _selectedVehicleIds.add(vehicleToSelect.id);
        } else if (displayVehicles.isNotEmpty) {
          _selectedVehicleId = displayVehicles.first.id;
          _selectedVehicleIds.clear();
          _selectedVehicleIds.add(displayVehicles.first.id);
        }

        _isLoadingVehicleStatus = false;
        _blockedDueToExistingSubscription =
            isNewSubscriptionPurchase && displayVehicles.isEmpty;
        _blockedVehicleMessage = _blockedDueToExistingSubscription
            ? 'All your vehicles have active subscriptions'
            : '';
      });
      print('[VEHICLES] Loading complete');
    } catch (e) {
      print('[VEHICLES] Error loading vehicles: $e');
      if (mounted) {
        setState(() {
          _isLoadingVehicleStatus = false;
        });
      }
    }
  }

  void _refreshDiscount() {
    if (_fromSubscriptionBooking) {
      setState(() {
        _discountAmount = _subtotal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Plan/Service Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _itemLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: PremiumTheme.orangePrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _itemName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (_itemDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _itemDescription,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Vehicle Selection
            Text(
              _fromSubscriptionBooking ? 'SELECTED VEHICLE' : 'VEHICLE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingVehicleStatus)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text('Loading vehicles...'),
                    ],
                  ),
                ),
              )
            else if (_blockedDueToExistingSubscription)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _blockedVehicleMessage.isNotEmpty
                            ? _blockedVehicleMessage
                            : 'All your vehicles have active subscriptions',
                        style: GoogleFonts.inter(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_vehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No vehicles added',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/edit-profile'),
                      child: const Text('Add vehicle in profile'),
                    ),
                  ],
                ),
              )
            else if (_isService && !_fromSubscriptionBooking)
              _buildServiceVehicleDropdown()
            else
              _buildSelectedVehicleCard(),

            // Time Slot Selection (only for standard care services)
            if (_isService && !_fromSubscriptionBooking) ...[
              const SizedBox(height: 24),
              Text(
                'SELECT TIME SLOT',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showTimeSlotPicker(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedTimeSlot ?? 'Choose a time slot',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selectedTimeSlot != null
                                ? const Color(0xFF0F172A)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUMMARY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isService ? 'Service Price' : 'Plan Price',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                      Text(
                        '₹${_basePrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (_vehicleCountForBilling > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vehicles',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        Text(
                          'x $_vehicleCountForBilling',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '₹${_total.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: PremiumTheme.orangePrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_fromSubscriptionBooking) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FREE - From Subscription',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    (user != null &&
                        !_blockedDueToExistingSubscription &&
                        _hasSelectableVehicle)
                    ? () => _processPayment(user.id)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.orangePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _total == 0
                      ? 'CONFIRM BOOKING'
                      : 'PAY ₹${_total.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedVehicleCard() {
    final selectedVehicle = _vehicles.isNotEmpty
        ? _vehicles.firstWhere(
            (v) => v.id == _selectedVehicleId,
            orElse: () => _vehicles.first,
          )
        : null;

    if (selectedVehicle == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Text('No vehicle selected'),
      );
    }

    final hasSubscription = _vehicleHasSubscription[selectedVehicle.id] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSubscription ? Colors.green : Colors.grey[200]!,
          width: hasSubscription ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE85A10).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: Color(0xFFE85A10),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedVehicle.model,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${selectedVehicle.licensePlate} • ${selectedVehicle.color}',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasSubscription)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'SUBSCRIBED',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceVehicleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVehicleId,
          isExpanded: true,
          hint: const Text('Choose a vehicle'),
          items: _vehicles.map((v) {
            final hasSub = _vehicleHasSubscription[v.id] == true;
            return DropdownMenuItem(
              value: v.id,
              child: Row(
                children: [
                  Expanded(child: Text('${v.model} • ${v.licensePlate}')),
                  if (hasSub)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SUBSCRIBED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedVehicleId = value),
        ),
      ),
    );
  }

  Widget _buildSubscriptionVehicleList() {
    final isNewSubscriptionPurchase = !_isService && !_fromSubscriptionBooking;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: _vehicles.map((v) {
          final selected = _selectedVehicleIds.contains(v.id);
          final hasSub = _vehicleHasSubscription[v.id] == true;
          final alreadyHasSubscription = isNewSubscriptionPurchase && hasSub;

          if (alreadyHasSubscription) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v.model} • ${v.licensePlate}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Already has active subscription',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ALREADY SUBSCRIBED',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return CheckboxListTile(
            value: selected,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Row(
              children: [
                Expanded(child: Text('${v.model} • ${v.licensePlate}')),
                if (hasSub)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FREE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedVehicleIds.add(v.id);
                } else {
                  _selectedVehicleIds.remove(v.id);
                }
                _refreshDiscount();
              });
            },
          );
        }).toList(),
      ),
    );
  }

  void _showTimeSlotPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimeSlotPicker(
        selectedDate: _selectedTimeSlot != null ? DateTime.now() : null,
        selectedTime: _selectedTimeSlot,
        showDatePicker: true,
        maxDaysAhead: 7,
        onConfirm: (date, time) {
          setState(() {
            _selectedTimeSlot = time;
          });
        },
      ),
    );
  }

  bool get _hasSelectableVehicle {
    // For services, must have a vehicle selected
    if (_isService) {
      return _selectedVehicleId != null && _vehicles.isNotEmpty;
    }

    // For subscription from booking (service from subscription), always allow
    if (_fromSubscriptionBooking) {
      return _selectedVehicleId != null || _selectedVehicleIds.isNotEmpty;
    }

    // For new subscription purchase, check if at least one vehicle can be subscribed
    // Also check for unknown status - if any vehicle has null status, don't allow purchase
    for (final v in _vehicles) {
      final hasSub = _vehicleHasSubscription[v.id];
      if (hasSub == null) return false; // Unknown status - block purchase
      if (!hasSub) return true; // Found a vehicle without subscription
    }
    return false;
  }

  Future<void> _processPayment(String userId) async {
    final dialogContext = context;
    print('[PAYMENT] Starting payment process for user: $userId');

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: PremiumTheme.orangePrimary),
      ),
    );

    try {
      print('[PAYMENT] Getting selected vehicles...');
      final selectedVehicles = _isService
          ? _vehicles.where((v) => v.id == _selectedVehicleId).toList()
          : _vehicles.where((v) => _selectedVehicleIds.contains(v.id)).toList();

      print('[PAYMENT] Selected vehicles count: ${selectedVehicles.length}');

      if (selectedVehicles.isEmpty) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vehicle')),
        );
        return;
      }

      // Validate time slot for standard care services
      if (_isService &&
          !_fromSubscriptionBooking &&
          _selectedTimeSlot == null) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot')),
        );
        return;
      }

      // Only validate for services FROM subscription (service from active subscription)
      // - Regular services: NO validation needed
      // - Subscription purchase: NO validation needed (only blocked if vehicle already has subscription)
      // - Service from subscription: YES validate (daily limits, same-day booking, etc.)
      final shouldValidate = _isService && _fromSubscriptionBooking;
      print(
        '[PAYMENT] Should validate: $shouldValidate (isService: $_isService, fromSubscription: $_fromSubscriptionBooking)',
      );

      if (shouldValidate) {
        for (final vehicle in selectedVehicles) {
          try {
            print('[PAYMENT] Validating vehicle: ${vehicle.licensePlate}');
            final validationError =
                await BookingValidationHelper.validateBooking(
                  userId: userId,
                  vehicleNumber: vehicle.licensePlate,
                  serviceId: _itemId,
                  planId: _subscriptionPlanId.isNotEmpty
                      ? _subscriptionPlanId
                      : null,
                  isSubscriptionBooking: _fromSubscriptionBooking,
                  context: context,
                ).timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    print(
                      '[PAYMENT] Validation timed out for: ${vehicle.licensePlate}',
                    );
                    return null;
                  },
                );

            if (validationError != null) {
              print('[PAYMENT] Validation error: $validationError');
              Navigator.pop(dialogContext);
              return;
            }
          } catch (e) {
            print('[PAYMENT] Validation exception: $e');
            // Allow booking to proceed if validation fails
          }
        }
      }

      print('[PAYMENT] Creating bookings...');
      final perVehiclePrice = _isService
          ? _total
          : _total / selectedVehicles.length;
      final bookingRepo = ref.read(bookingRepositoryProvider);
      final now = DateTime.now();
      final createdBookingIds = <String>[];

      for (final vehicle in selectedVehicles) {
        try {
          print('[PAYMENT] Creating booking for: ${vehicle.licensePlate}');

          // Calculate subscription period end based on duration
          DateTime? subscriptionPeriodEnd;
          if (_fromSubscriptionBooking) {
            final isYearly =
                _subscriptionDuration.toLowerCase().contains('yearly') ||
                _subscriptionDuration.isEmpty;
            subscriptionPeriodEnd = now.add(
              Duration(days: isYearly ? 365 : 30),
            );
          }

          final booking = BookingModel(
            id: '',
            userId: userId,
            serviceId: _encodedItemRef(),
            vehicleName: vehicle.model,
            vehicleNumber: vehicle.licensePlate,
            vehicleId: vehicle.id,
            subscriptionVehicleId: _fromSubscriptionBooking ? vehicle.id : null,
            appointmentDate: now,
            status: BookingStatus.confirmed,
            totalPrice: perVehiclePrice,
            qrCodeData:
                'DG-${userId.substring(0, 8).toUpperCase()}-${now.millisecondsSinceEpoch}-${vehicle.id.substring(0, 4)}',
            createdAt: now,
            isSubscriptionBooking: _fromSubscriptionBooking,
            planId: _subscriptionPlanId.isNotEmpty ? _subscriptionPlanId : null,
            subscriptionPeriodStart: _fromSubscriptionBooking ? now : null,
            subscriptionPeriodEnd: subscriptionPeriodEnd,
            originalPurchaseDate: _fromSubscriptionBooking ? now : null,
            scheduledTime: _selectedTimeSlot,
          );

          print('[PAYMENT] Calling bookingRepo.createBooking...');
          final createdId = await bookingRepo
              .createBooking(booking)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  print('[PAYMENT] Booking creation timed out');
                  throw Exception(
                    'Booking creation timed out. Please try again.',
                  );
                },
              );
          print('[PAYMENT] Booking created with ID: $createdId');
          createdBookingIds.add(createdId);
        } catch (e) {
          print('[PAYMENT] Booking exception: $e');
          Navigator.pop(dialogContext);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      print('[PAYMENT] Payment successful, navigating to success page');
      Navigator.pop(dialogContext);
      if (mounted) {
        // Navigate to booking page with success message
        // For subscriptions, go to My Subscription tab to show new subscription
        // For services, go to My Booking tab
        final openTab = _isService ? 'active' : 'subscriptions';

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/booking',
          (route) => false,
          arguments: {
            'openTab': openTab,
            'refresh': true, // Trigger data refresh
            'bookingIds': createdBookingIds,
            'isService': _isService,
            'itemName': _itemName,
            'total': _total,
            'vehicleCount': selectedVehicles.length,
          },
        );
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isService
                  ? 'Service booked successfully!'
                  : 'Subscription activated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _encodedItemRef() {
    if (_isService && _fromSubscriptionBooking) {
      final planId = _subscriptionPlanId.isNotEmpty
          ? _subscriptionPlanId
          : 'unknown_subscription';
      final serviceId = _itemId.isNotEmpty ? _itemId : 'unknown_service';
      return 'subscription_service::$planId::$serviceId::${_itemName.trim()}';
    }

    if (_isService) {
      final id = _itemId.isNotEmpty ? _itemId : 'unknown_service';
      return 'service::$id::${_itemName.trim()}';
    }

    final id = _itemId.isNotEmpty ? _itemId : 'unknown_subscription';
    return 'subscription::$id::${_itemName.trim()}';
  }
}

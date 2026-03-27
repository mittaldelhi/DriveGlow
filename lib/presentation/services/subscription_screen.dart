import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/providers/subscription_plan_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/models/subscription_plan_model.dart';
import '../../domain/models/vehicle_model.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _billingPeriod = 'Yearly';
  late Future<_CurrentPlanContext?> _currentPlanFuture;
  List<VehicleModel> _vehicles = [];
  VehicleModel? _selectedVehicle;
  bool _isLoadingVehicles = true;
  String? _preselectedVehicleId;
  String? _preselectedVehicleNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _preselectedVehicleId = args['preselectedVehicleId'] as String?;
        _preselectedVehicleNumber = args['preselectedVehicleNumber'] as String?;
      }
    });
    _currentPlanFuture = _loadCurrentPlanContext();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingVehicles = false);
      return;
    }

    try {
      final response = await client
          .from('user_vehicles')
          .select('id, model, license_plate, color, is_primary')
          .eq('user_id', user.id);

      final vehicles = (response as List)
          .map((v) => VehicleModel.fromJson(v))
          .toList();

      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoadingVehicles = false;
          
          if (_preselectedVehicleId != null && _preselectedVehicleNumber != null) {
            try {
              _selectedVehicle = vehicles.firstWhere(
                (v) => v.id == _preselectedVehicleId || v.licensePlate == _preselectedVehicleNumber,
              );
            } catch (e) {
              _selectedVehicle = vehicles.isNotEmpty ? vehicles.firstWhere(
                (v) => v.isPrimary,
                orElse: () => vehicles.first,
              ) : null;
            }
          } else if (vehicles.isNotEmpty && _selectedVehicle == null) {
            _selectedVehicle = vehicles.firstWhere(
              (v) => v.isPrimary,
              orElse: () => vehicles.first,
            );
          }
        });
        _currentPlanFuture = _loadCurrentPlanContext();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
      }
    }
  }

  Future<_CurrentPlanContext?> _loadCurrentPlanContext() async {
    if (_selectedVehicle == null) return null;
    
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;

    final bookingRows = await client
        .from('bookings')
        .select('service_id,created_at,status,vehicle_number')
        .eq('user_id', user.id)
        .like('service_id', 'subscription::%')
        .neq('status', 'cancelled')
        .eq('vehicle_number', _selectedVehicle!.licensePlate.toUpperCase())
        .order('created_at', ascending: false)
        .limit(1);

    if ((bookingRows as List).isEmpty) return null;
    final serviceId = (bookingRows.first['service_id'] ?? '').toString();
    final parts = serviceId.split('::');
    if (parts.length < 3) return null;
    final planId = parts[1];
    final planName = parts.sublist(2).join('::');

    try {
      final plan = await client
          .from('subscription_plans')
          .select('id,duration,name')
          .eq('id', planId)
          .maybeSingle();
      if (plan != null) {
        final duration = _normalizeDuration((plan['duration'] ?? '').toString());
        return _CurrentPlanContext(
          planId: planId,
          planName: (plan['name'] ?? planName).toString(),
          duration: duration,
        );
      }
    } catch (_) {}

    return _CurrentPlanContext(
      planId: planId,
      planName: planName,
      duration: _normalizeDuration(planName),
    );
  }

  String _normalizeDuration(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('year')) return 'Yearly';
    if (lower.contains('month')) return 'Monthly';
    return '';
  }

  Widget _buildVehicleDropdown() {
    if (_isLoadingVehicles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please add a vehicle first to purchase subscription',
                style: GoogleFonts.inter(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VehicleModel>(
          value: _selectedVehicle,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          hint: Text(
            'Select Vehicle',
            style: GoogleFonts.inter(color: Colors.grey[600]),
          ),
          items: _vehicles.map((vehicle) {
            return DropdownMenuItem<VehicleModel>(
              value: vehicle,
              child: Row(
                children: [
                  Icon(Icons.directions_car, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vehicle.model,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          vehicle.licensePlate,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (vehicle) {
            if (vehicle != null) {
              setState(() {
                _selectedVehicle = vehicle;
                _currentPlanFuture = _loadCurrentPlanContext();
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(
      subscriptionPlansByDurationProvider(_billingPeriod),
    );

    return FutureBuilder<_CurrentPlanContext?>(
      future: _currentPlanFuture,
      builder: (context, currentSnapshot) {
        final currentPlan = currentSnapshot.data;
        if (currentPlan?.duration == 'Yearly' && _billingPeriod != 'Yearly') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _billingPeriod = 'Yearly');
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F6F6),
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Subscription Plans',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
            body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Text(
                      'Choose Your Plan',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentPlan == null
                          ? 'Choose a monthly or yearly plan.'
                          : currentPlan.duration == 'Monthly'
                              ? 'Current plan is Monthly. Upgrade to Yearly only.'
                              : 'Current plan is Yearly. Downgrade is disabled.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_vehicles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildVehicleDropdown(),
                    ],
                  ],
                ),
              ),
            ),

            // Billing Toggle
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyToggleDelegate(
                  child: Container(
                    color: const Color(0xFFF8F6F6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  child: _buildBillingToggle(currentPlan),
                ),
              ),
            ),

            // Plans
            SliverToBoxAdapter(
              child: plansAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFF0541E)),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load plans',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            subscriptionPlansByDurationProvider(_billingPeriod),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (plans) => _buildPlansContent(plans, currentPlan),
              ),
            ),

            // Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Text(
                      'By selecting a plan, you agree to our Terms of Service. Plans automatically renew unless cancelled 24h before end of period.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Cancel Subscription',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlansContent(
    List<SubscriptionPlanModel> plans,
    _CurrentPlanContext? currentPlan,
  ) {
    if (plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.card_membership_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No plans available',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Group plans by vehicle category
    final grouped = <String, List<SubscriptionPlanModel>>{};
    for (final plan in plans) {
      grouped.putIfAbsent(plan.vehicleCategory, () => []).add(plan);
    }

    // Vehicle category icons
    final categoryIcons = <String, IconData>{
      'Sedan': Icons.directions_car,
      'SUV': Icons.local_shipping,
      'Truck': Icons.airport_shuttle,
    };

    return Column(
      children: grouped.entries.map((entry) {
        final categoryPlans = entry.value;
        final featuredPlan = categoryPlans.where((p) => p.isFeatured).toList();
        final regularPlans = categoryPlans.where((p) => !p.isFeatured).toList();

        return Column(
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: _buildCategoryHeader(
                entry.key,
                categoryIcons[entry.key] ?? Icons.directions_car,
              ),
            ),
            // Featured plans (Platinum style)
            ...featuredPlan.map(
              (plan) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildFeaturedPlanCard(plan, currentPlan),
              ),
            ),
            // Regular plans
            ...regularPlans.map(
              (plan) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: _buildStandardPlanCard(plan, currentPlan),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBillingToggle(_CurrentPlanContext? currentPlan) {
    final yearlyLocked = currentPlan?.duration == 'Yearly';
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _buildToggleOption('Monthly', 'Monthly', disabled: yearlyLocked),
          _buildToggleOption('Yearly', 'Yearly', hasBadge: true),
        ],
      ),
    );
  }

  Widget _buildToggleOption(
    String value,
    String label, {
    bool hasBadge = false,
    bool disabled = false,
  }) {
    final isSelected = _billingPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : () => setState(() => _billingPeriod = value),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: disabled
                      ? Colors.grey[300]
                      : isSelected
                          ? Colors.white
                          : Colors.grey[400],
                ),
              ),
              if (hasBadge && _billingPeriod == 'Yearly')
                Positioned(
                  top: -20,
                  right: -30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'SAVE 20%',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String category, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(width: 8),
        Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardPlanCard(
    SubscriptionPlanModel plan,
    _CurrentPlanContext? currentPlan,
  ) {
    final state = _planActionState(plan, currentPlan);
    final tierColors = <String, Color>{
      'Silver': const Color(0xFF94A3B8),
      'Gold': const Color(0xFFD4AF37),
      'Platinum': const Color(0xFF1E3A8A),
    };
    final tierColor = tierColors[plan.tier] ?? const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (plan.savingsText != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Text(
                  plan.savingsText!,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tierColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              plan.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.showUnlimited 
                              ? 'Unlimited services/month' 
                              : '${plan.serviceUsageLimits?.values.fold(0, (sum, v) => sum + v) ?? 0} services/month',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${plan.price.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (plan.originalPrice != null)
                          Text(
                            '₹${plan.originalPrice!.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey[100]),
                const SizedBox(height: 16),
                // Features
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: plan.features
                      .map(
                        (f) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              f,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (currentPlan != null && currentPlan.planId == plan.id)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Already Subscribed for this vehicle',
                          style: GoogleFonts.inter(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: state.canProceed
                      ? () {
                          final isGuest = ref.read(isGuestProvider);
                          if (isGuest) {
                            Navigator.pushNamed(context, '/login');
                          } else {
                            Navigator.pushNamed(
                              context,
                              '/payment',
                              arguments: {
                                'isService': false,
                                'planId': plan.id,
                                'planName': plan.name,
                                'duration': plan.duration,
                                'price': plan.price,
                                'selectedVehicleId': _selectedVehicle?.id,
                                'selectedVehicleNumber': _selectedVehicle?.licensePlate,
                              },
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[50],
                    foregroundColor: Colors.grey[800],
                    minimumSize: const Size(double.infinity, 50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    state.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPlanCard(
    SubscriptionPlanModel plan,
    _CurrentPlanContext? currentPlan,
  ) {
    final state = _planActionState(plan, currentPlan);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.amber[400]!.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Savings badge
          if (plan.savingsText != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Text(
                  '${plan.savingsText} vs Monthly',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber[400],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.diamond,
                      color: Color(0xFFD4AF37),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.all_inclusive,
                      color: Color(0xFFD4AF37),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.showUnlimited 
                            ? 'Unlimited services/month' 
                            : '${plan.serviceUsageLimits?.values.fold(0, (sum, v) => sum + v) ?? 0} services/month',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[100],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Features
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: plan.features
                        .map(
                          (f) => _buildPlatinumFeature(
                            f,
                            isBold: f == plan.features.first,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan.duration.toUpperCase()} PRICE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[400],
                            letterSpacing: 1.0,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${plan.price.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            if (plan.originalPrice != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${plan.originalPrice!.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (plan.monthlyEquivalent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[400]!.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plan.monthlyEquivalent!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Already subscribed badge
                if (currentPlan != null && currentPlan.planId == plan.id)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Already Subscribed for this vehicle',
                          style: GoogleFonts.inter(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                // CTA
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFF5DE78)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: state.canProceed
                        ? () {
                            final isGuest = ref.read(isGuestProvider);
                            if (isGuest) {
                              Navigator.pushNamed(context, '/login');
                            } else {
                              Navigator.pushNamed(
                                context,
                                '/payment',
                                arguments: {
                                  'isService': false,
                                  'planId': plan.id,
                                  'planName': plan.name,
                                  'duration': plan.duration,
                                  'price': plan.price,
                                  'selectedVehicleId': _selectedVehicle?.id,
                                  'selectedVehicleNumber': _selectedVehicle?.licensePlate,
                                },
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF0F172A),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.label,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatinumFeature(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.green[400]!.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 12, color: Color(0xFF4ADE80)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: Colors.grey[200],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _PlanActionState _planActionState(
    SubscriptionPlanModel plan,
    _CurrentPlanContext? currentPlan,
  ) {
    if (currentPlan == null) {
      return const _PlanActionState(canProceed: true, label: 'Select Plan');
    }
    if (currentPlan.planId == plan.id) {
      return const _PlanActionState(canProceed: false, label: 'Current Plan');
    }

    final currentDuration = _normalizeDuration(currentPlan.duration);
    final targetDuration = _normalizeDuration(plan.duration);
    if (currentDuration == 'Yearly' && targetDuration == 'Monthly') {
      return const _PlanActionState(canProceed: false, label: 'Downgrade Disabled');
    }
    if (currentDuration == 'Monthly' && targetDuration == 'Yearly') {
      return const _PlanActionState(canProceed: true, label: 'Upgrade to Yearly');
    }
    if (currentDuration == targetDuration) {
      return const _PlanActionState(canProceed: false, label: 'Current Duration');
    }
    return const _PlanActionState(canProceed: false, label: 'Not Available');
  }
}

class _StickyToggleDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyToggleDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class _CurrentPlanContext {
  final String planId;
  final String planName;
  final String duration;

  const _CurrentPlanContext({
    required this.planId,
    required this.planName,
    required this.duration,
  });
}

class _PlanActionState {
  final bool canProceed;
  final String label;

  const _PlanActionState({required this.canProceed, required this.label});
}

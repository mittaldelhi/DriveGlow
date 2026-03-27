import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../application/providers/standard_service_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../application/helpers/booking_validation_helper.dart';
import '../../domain/models/standard_service_model.dart';
import '../../theme/app_theme.dart';

class SubscriptionServicesBookingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRefresh;  // Callback to trigger parent refresh

  const SubscriptionServicesBookingScreen({super.key, this.onRefresh});

  @override
  ConsumerState<SubscriptionServicesBookingScreen> createState() => _SubscriptionServicesBookingScreenState();
}

class _SubscriptionServicesBookingScreenState extends ConsumerState<SubscriptionServicesBookingScreen> {
  bool _isLoading = true;
  bool _isCancelling = false;
  Map<String, int> _serviceUsage = {};
  bool _hasBookedToday = false;
  
  // Subscription data from arguments
  String _planId = '';
  String _planName = 'Subscription';
  String _duration = '';
  String _vehicleNumber = '';
  int _totalServices = 0;
  String _expiresAt = '';
  List<String> _allowedServiceIds = [];
  Map<String, int> _serviceLimits = {}; // Per-service limits
  int _dailyLimit = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    setState(() {
      _planId = args?['planId'] as String? ?? '';
      _planName = args?['planName'] as String? ?? 'Subscription';
      _duration = args?['duration'] as String? ?? '';
      _vehicleNumber = args?['vehicleNumber'] as String? ?? '';
      _totalServices = args?['totalAllowed'] as int? ?? 0;
      _expiresAt = args?['expiresAt'] as String? ?? '';
      _allowedServiceIds = (args?['allowedServiceIds'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      
      // Load per-service limits from arguments
      final serviceLimitsArg = args?['serviceLimits'] as Map<String, dynamic>?;
      if (serviceLimitsArg != null) {
        _serviceLimits = serviceLimitsArg.map((key, value) => MapEntry(key.toString(), (value as num).toInt()));
      }
      
      _dailyLimit = args?['dailyLimit'] as int? ?? 1;
      _isLoading = false;
    });
    
    _loadServiceUsage();
  }

  Future<void> _loadServiceUsage() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _vehicleNumber.isEmpty || _allowedServiceIds.isEmpty) return;
    
    try {
      final usage = await BookingValidationHelper.getPerServiceUsage(
        userId: user.id,
        vehicleNumber: _vehicleNumber,
        planId: _planId,
        includedServiceIds: _allowedServiceIds,
      );
      
      // Check daily limit
      final hasBookedToday = await BookingValidationHelper.hasBookedTodayForSubscription(
        userId: user.id,
        planId: _planId,
        vehicleNumber: _vehicleNumber,
      );
      
      if (mounted) {
        setState(() {
          _serviceUsage = usage;
          _hasBookedToday = hasBookedToday;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _cancelSubscription() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _vehicleNumber.isEmpty || _planId.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text('Are you sure you want to cancel the subscription for $_vehicleNumber? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performCancellation(user.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancellation(String userId) async {
    setState(() => _isCancelling = true);

    try {
      // Find subscription booking using plan_id filter instead of is_subscription_booking column
      final existingBookings = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('vehicle_number', _vehicleNumber.toUpperCase())
          .eq('plan_id', _planId)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (existingBookings.isNotEmpty) {
        final bookingId = existingBookings.first['id'];
        await Supabase.instance.client
            .from('bookings')
            .update({'status': 'cancelled'})
            .eq('id', bookingId)
            .timeout(const Duration(seconds: 10));
      } else {
        // Try alternative query - check by service_id pattern
        final altBookings = await Supabase.instance.client
            .from('bookings')
            .select('id')
            .eq('user_id', userId)
            .eq('vehicle_number', _vehicleNumber.toUpperCase())
            .neq('status', 'cancelled')
            .neq('status', 'completed')
            .neq('status', 'lapsed')
            .order('created_at', ascending: false)
            .limit(5)
            .timeout(const Duration(seconds: 10));
        
        for (final b in altBookings) {
          final serviceId = (b['service_id'] ?? '').toString();
          if (serviceId.contains('subscription') || serviceId.contains(_planId)) {
            await Supabase.instance.client
                .from('bookings')
                .update({'status': 'cancelled'})
                .eq('id', b['id'])
                .timeout(const Duration(seconds: 10));
            break;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled'),
            backgroundColor: Colors.green,
          ),
        );
        // Trigger parent refresh
        widget.onRefresh?.call();
        // Navigate back
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeStandardServicesProvider);

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
          'My Subscription',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _buildBody(servicesAsync),
    );
  }

  Widget _buildBody(AsyncValue<List<StandardServiceModel>> servicesAsync) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeStandardServicesProvider);
        await _loadServiceUsage();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subscription Details Card
          _buildSubscriptionCard(),
          
          const SizedBox(height: 24),
          
          // Available Services Header
          Text(
            'AVAILABLE SERVICES',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Services List
          servicesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => _buildServicesError(err.toString()),
            data: (services) => _buildServicesList(services),
          ),

          const SizedBox(height: 24),

          // Fair Usage Policy
          _buildFairUsagePolicy(),
        ],
      ),
    );
  }

  Widget _buildFairUsagePolicy() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '*Fair Usage Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showFairUsageDialog(),
                child: Text(
                  'Learn More',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.orangePrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          if (_dailyLimit > 0) ...[
            const SizedBox(height: 8),
            Text(
              '• Daily Limit: $_dailyLimit service${_dailyLimit > 1 ? 's' : ''} per day from this subscription',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
          if (_duration == 'Yearly') ...[
            const SizedBox(height: 4),
            Text(
              '• Monthly counter resets every 30 days',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  void _showFairUsageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: PremiumTheme.orangePrimary),
            const SizedBox(width: 8),
            Text('Fair Usage Policy', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Subscription Benefits',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (_serviceLimits.isNotEmpty) ...[
                ..._serviceLimits.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(e.key, style: GoogleFonts.inter(fontSize: 13))),
                      Text(
                        '${e.value}/month',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                )),
                const Divider(),
              ],
              if (_totalServices > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Monthly Services', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    Text('$_totalServices', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ],
                ),
                if (_duration == 'Yearly') ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Yearly Total', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                      Text('${_totalServices * 12}/year', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daily Limit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  Text('$_dailyLimit service${_dailyLimit > 1 ? 's' : ''}/day', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ],
              ),
              if (_duration == 'Yearly') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    Text('Every 30 days', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Important Notes',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildPolicyPoint('Unused services do not carry forward'),
              _buildPolicyPoint('Services must be used within validity period'),
              _buildPolicyPoint('One service per day limit applies'),
              _buildPolicyPoint('Cancelled services count as used'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.inter(fontSize: 12)),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final isExpired = _expiresAt.isNotEmpty && DateTime.now().isAfter(DateTime.tryParse(_expiresAt) ?? DateTime.now());
    final daysRemaining = _expiresAt.isNotEmpty 
        ? DateTime.now().difference(DateTime.tryParse(_expiresAt) ?? DateTime.now()).inDays.abs()
        : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PremiumTheme.orangePrimary,
            PremiumTheme.orangePrimary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.orangePrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _planName.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (_duration.isNotEmpty)
                        Text(
                          _duration,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'EXPIRED' : 'ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Vehicle Info
            if (_vehicleNumber.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleNumber.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Subscribed Vehicle',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Expiry Info
            if (_expiresAt.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.white.withValues(alpha: 0.8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isExpired 
                        ? 'Expired on ${DateFormat('MMM dd, yyyy').format(DateTime.tryParse(_expiresAt) ?? DateTime.now())}'
                        : 'Valid till ${DateFormat('MMM dd, yyyy').format(DateTime.tryParse(_expiresAt) ?? DateTime.now())} ($daysRemaining days)',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            
            const SizedBox(height: 20),
            
            // Contact Support Message (Subscriptions can only be cancelled by admin)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contact support to cancel subscription',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
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

  Widget _buildServicesError(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 48),
          const SizedBox(height: 12),
          Text(
            'Failed to load services',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => ref.invalidate(activeStandardServicesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(List<StandardServiceModel> services) {
    if (_allowedServiceIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.settings_applications, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No services configured',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact admin to add services to your subscription plan.',
              style: GoogleFonts.inter(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filtered = services.where((s) => _allowedServiceIds.contains(s.id)).toList();
    
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No matching services found',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((service) => _buildServiceCard(service)).toList(),
    );
  }

  Widget _buildServiceCard(StandardServiceModel service) {
    final usedCount = _serviceUsage[service.id] ?? 0;
    final int maxUses = _serviceLimits[service.id] ?? (_totalServices > 0 ? _totalServices : 999);
    final remaining = maxUses - usedCount;
    final hasServiceLimit = maxUses != 999;
    final canBook = !_hasBookedToday && (!hasServiceLimit || usedCount < maxUses);
    final progressPercent = maxUses > 0 ? (usedCount / maxUses).clamp(0.0, 1.0) : 0.0;
    final isUnlimited = maxUses == 999;
    
    // Button is disabled if booked today OR if service limit reached
    final isButtonDisabled = _hasBookedToday || !canBook;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.car_repair, color: PremiumTheme.orangePrimary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.description,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Usage Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isUnlimited ? 'Usage (Unlimited)' : 'Usage',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  if (!isUnlimited)
                    Text(
                      '$usedCount / $maxUses',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[800]),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          '∞',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: PremiumTheme.orangePrimary),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'UNLIMITED',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: PremiumTheme.orangePrimary),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (!isUnlimited) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent > 0.7 ? Colors.orange : PremiumTheme.orangePrimary,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Used: $usedCount',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      remaining >= 0 ? 'Remaining: $remaining' : 'Over limit',
                      style: GoogleFonts.inter(
                        fontSize: 11, 
                        fontWeight: FontWeight.w600,
                        color: remaining > 0 ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Book Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonDisabled
                  ? null
                  : () {
                      final isGuest = ref.read(isGuestProvider);
                      if (isGuest) {
                        Navigator.pushNamed(context, '/login');
                      } else {
                        Navigator.pushNamed(context, '/payment', arguments: {
                          'isService': true,
                          'serviceId': service.id,
                          'serviceName': service.name,
                          'serviceDescription': service.description,
                          'servicePrice': service.price,
                          'fromSubscriptionBooking': true,
                          'subscriptionPlanId': _planId,
                          'subscriptionPlanName': _planName,
                          'autoCouponName': 'Subscription',
                          'selectedVehicleNumber': _vehicleNumber,
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonDisabled ? Colors.grey[400] : PremiumTheme.orangePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _hasBookedToday ? 'BOOKED TODAY' : (canBook ? 'BOOK NOW' : 'LIMIT REACHED'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

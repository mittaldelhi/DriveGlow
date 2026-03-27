import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/providers/feature_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/models/service_pricing_model.dart';
import '../../../theme/app_theme.dart';

class ServiceSelectionScreen extends ConsumerStatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  ConsumerState<ServiceSelectionScreen> createState() =>
      _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState
    extends ConsumerState<ServiceSelectionScreen> {
  int _selectedTabIndex = 0; // 0: One-Time, 1: Subscription
  String _subscriptionDuration = 'Monthly'; // 'Monthly', 'Yearly'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        title: const Text(
          'Select Service',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── Main Tabs (One Time vs Subscription) ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    _buildMainTab('One Time', 0),
                    _buildMainTab('Subscription', 1),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ─── Subscription Sub-Toggle ───
          if (_selectedTabIndex == 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSubToggle('Monthly'),
                    const SizedBox(width: 12),
                    _buildSubToggle('Yearly'),
                  ],
                ),
              ),
            ),

          // ─── Service List ───
          SliverToBoxAdapter(
            child: _selectedTabIndex == 0
                ? _buildOneTimeServices()
                : _buildSubscriptionServices(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  /// Build One-Time Services Section
  Widget _buildOneTimeServices() {
    final servicesAsync = ref.watch(oneTimeServicesProvider);

    return servicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: PremiumTheme.orangePrimary),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Error loading services',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No one-time services available',
                style: GoogleFonts.inter(color: Colors.grey[500]),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${services.length} services available',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ...services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildServiceCard(ref, service, isSubscription: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Subscription Services Section
  Widget _buildSubscriptionServices() {
    final plansAsync = ref.watch(
      subscriptionServicesByDurationProvider(_subscriptionDuration),
    );

    return plansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: PremiumTheme.orangePrimary),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Error loading subscription plans',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (plans) {
        if (plans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No $_subscriptionDuration subscription plans available',
                style: GoogleFonts.inter(color: Colors.grey[500]),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plans.length} $_subscriptionDuration plans available',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ...plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSubscriptionPlanCard(plan),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tab Toggle - One Time vs Subscription
  Widget _buildMainTab(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? PremiumTheme.orangePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// Duration Toggle - Monthly vs Yearly
  Widget _buildSubToggle(String duration) {
    final isSelected = _subscriptionDuration == duration;
    return GestureDetector(
      onTap: () => setState(() => _subscriptionDuration = duration),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7F2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          duration,
          style: TextStyle(
            color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// One-Time Service Card
  Widget _buildServiceCard(
    WidgetRef ref,
    ServicePricingModel service, {
    bool isSubscription = false,
  }) {
    return GestureDetector(
      onTap: () {
        final isGuest = ref.read(isGuestProvider);
        if (isGuest) {
          Navigator.pushNamed(context, '/login');
        } else {
          Navigator.pushNamed(
            context,
            '/payment',
            arguments: {
              'serviceId': service.id,
              'serviceName': service.name,
              'price': service.price,
              'category': service.category,
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: const Color(0xFF0EA5E9),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              service.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            if (service.description.isNotEmpty)
              Text(
                service.description,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (service.description.isEmpty)
              Text(
                'Category: ${service.category}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${service.price.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final isGuest = ref.read(isGuestProvider);
                  if (isGuest) {
                    Navigator.pushNamed(context, '/login');
                  } else {
                    Navigator.pushNamed(
                      context,
                      '/payment',
                      arguments: {
                        'serviceId': service.id,
                        'serviceName': service.name,
                        'price': service.price,
                        'category': service.category,
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.orangePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Subscription Plan Card
  Widget _buildSubscriptionPlanCard(ServicePricingModel plan) {
    return GestureDetector(
      onTap: () {
        final isGuest = ref.read(isGuestProvider);
        if (isGuest) {
          Navigator.pushNamed(context, '/login');
        } else {
          Navigator.pushNamed(
            context,
            '/payment',
            arguments: {
              'serviceId': plan.id,
              'serviceName': plan.name,
              'price': plan.price,
              'category': plan.category,
              'isSubscription': false,
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.serviceName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.category,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '/one-time',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PremiumTheme.orangePrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${plan.price.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'one-time service',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: TextStyle(
                  color: Colors.amber[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final isGuest = ref.read(isGuestProvider);
                  if (isGuest) {
                    Navigator.pushNamed(context, '/login');
                  } else {
                    Navigator.pushNamed(
                      context,
                      '/payment',
                      arguments: {
                        'serviceId': plan.id,
                        'serviceName': plan.name,
                        'price': plan.price,
                        'category': plan.category,
                        'isSubscription': false,
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.orangePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Subscribe Now',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

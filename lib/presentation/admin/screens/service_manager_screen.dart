import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/feature_providers.dart';
import '../../../domain/models/service_pricing_model.dart';
import '../widgets/admin_scaffold.dart';

class AdminServiceManagerScreen extends ConsumerStatefulWidget {
  const AdminServiceManagerScreen({super.key});

  @override
  ConsumerState<AdminServiceManagerScreen> createState() =>
      _AdminServiceManagerScreenState();
}

class _AdminServiceManagerScreenState
    extends ConsumerState<AdminServiceManagerScreen> {
  String _activeTab = 'Standard Care';

  @override
  Widget build(BuildContext context) {
    final pricingAsync = ref.watch(servicePricingProvider(_activeTab));

    return AdminScaffold(
      initialIndex: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0541E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Service Manager',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: Color(0xFF1A1A1A),
              ),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/admin_avatar.png'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            _buildTopTabs(),
            Expanded(
              child: pricingAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF0541E)),
                ),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (pricing) => _buildPricingView(pricing),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Standard Care', 'Accessories', 'Maintenance'].map((tab) {
          final isSelected = _activeTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFF0541E)
                        : Colors.grey[600],
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPricingView(List<ServicePricingModel> pricing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),

          // Section: Car Wash Packages (One-Time)
          _buildSectionHeader('CAR WASH PACKAGES', 'SYNC'),
          _buildMatrixTable(pricing, 'One-Time'),
          const SizedBox(height: 32),

          // Section: Subscription Models (Monthly/Yearly)
          _buildSectionHeader('SUBSCRIPTION MODELS', 'MANAGE'),
          _buildMatrixTable(pricing, 'Monthly'),
          const SizedBox(height: 16),
          _buildMatrixTable(pricing, 'Yearly'),
          const SizedBox(height: 32),

          // Section: Special Services
          _buildSectionHeader('SPECIAL SERVICES', 'ADD'),
          _buildSpecialServicesList(pricing),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionLabel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            actionLabel,
            style: const TextStyle(
              color: Color(0xFFF0541E),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(List<ServicePricingModel> pricing, String planType) {
    // Deprecated: service_pricing table now contains only one-time services
    // Matrix table used for old tier-based pricing (SEDAN/SUV/LUX) - no longer needed
    return const SizedBox.shrink();
  }

  Widget _buildSpecialServicesList(List<ServicePricingModel> pricing) {
    // Deprecated: use subscription plan management instead
    // Special services were stored in old service_pricing table - now managed separately
    return const SizedBox.shrink();
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search services...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: const Icon(Icons.tune, color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }
}

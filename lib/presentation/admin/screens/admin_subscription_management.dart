import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers/subscription_plan_stream_providers.dart';
import '../../../application/providers/standard_service_stream_providers.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../domain/models/subscription_plan_model.dart';
import '../../../domain/models/standard_service_model.dart';
import '../../../theme/app_theme.dart';

class AdminSubscriptionManagementScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionManagementScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionManagementScreen> createState() => _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState extends ConsumerState<AdminSubscriptionManagementScreen> {
  String _filterDuration = 'All';
  bool _isAdmin = true;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(streamAllSubscriptionPlansProvider);
    final servicesAsync = ref.watch(streamAllStandardServicesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0541E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_membership_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Subscriptions',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            if (_isAdmin)
              TextButton.icon(
                onPressed: () {
                  final services = servicesAsync.value ?? [];
                  _showSubscriptionDialog(context, services);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0541E)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF0541E))),
          error: (err, _) {
            final isTableError = err.toString().contains('PGRST116') || err.toString().contains('subscription_plans');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Error Loading Subscriptions', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    isTableError ? 'The subscription_plans table was not found.\nMigration required.' : 'Error: $err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(streamAllSubscriptionPlansProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
          data: (plans) {
            final services = servicesAsync.value ?? [];
            return _buildBody(plans, services);
          },
        ),
        bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: PremiumTheme.orangePrimary,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pop(context);
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/admin/dashboard');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/admin/settings');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/admin/profile');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<SubscriptionPlanModel> plans, List<StandardServiceModel> services) {
    final durations = ['All', 'Monthly', 'Yearly'];
    final filtered = _filterDuration == 'All' ? plans : plans.where((p) => p.duration == _filterDuration).toList();

    return Column(
      children: [
        // Duration filter chips
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: durations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final duration = durations[index];
              final isSelected = _filterDuration == duration;
              return FilterChip(
                selected: isSelected,
                label: Text(duration, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.grey[600])),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey[300]!)),
                onSelected: (_) => setState(() => _filterDuration = duration),
              );
            },
          ),
        ),
        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildStatChip('${plans.length} Total', Icons.dashboard_rounded, const Color(0xFF667EEA)),
              const SizedBox(width: 8),
              _buildStatChip('${plans.where((p) => p.isActive).length} Active', Icons.check_circle_rounded, const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _buildStatChip('${plans.where((p) => !p.isActive).length} Inactive', Icons.visibility_off_rounded, Colors.grey),
            ],
          ),
        ),
        // Plan list
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No subscription plans', style: GoogleFonts.inter(color: Colors.grey[500])))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _buildSubscriptionTile(filtered[index], services),
                ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTile(SubscriptionPlanModel plan, List<StandardServiceModel> services) {
    final includedServices = plan.includedServiceIds ?? [];
    final features = plan.features ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          _buildTierBadge(plan.tier),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${plan.vehicleCategory} • ${plan.duration}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (plan.originalPrice != null && plan.originalPrice! > plan.price)
                          Text('₹${plan.originalPrice!.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey[400], fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('₹${plan.price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFFE85A10))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(plan.isActive ? 'Active' : 'Inactive'),
                      backgroundColor: plan.isActive ? Colors.green[100] : Colors.red[100],
                      labelStyle: TextStyle(color: plan.isActive ? Colors.green[700] : Colors.red[700], fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Service Usage Limits
            if (plan.serviceUsageLimits != null && plan.serviceUsageLimits!.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.serviceUsageLimits!.values.fold(0, (sum, v) => sum + v)} services/month',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            // Description
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Description:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(plan.description, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            // Unlimited badge
            if (plan.showUnlimited) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.all_inclusive_rounded, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text('Unlimited Washes', style: TextStyle(color: Colors.green[700], fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            // Monthly Cap Override
            if (plan.monthlyCapOverride != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text('Monthly Cap: ${plan.monthlyCapOverride} washes', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                ],
              ),
            ],
            // Features
            if (features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Features:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: features.map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF0541E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(f, style: const TextStyle(fontSize: 11, color: Color(0xFFF0541E))),
                )).toList(),
              ),
            ],
            // Included Services
            if (includedServices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.build_rounded, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text('${includedServices.length} Services Included', style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            // Toggle Active
            if (_isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Availability:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  OutlinedButton.icon(
                    onPressed: () => _togglePlanStatus(plan),
                    icon: Icon(plan.isActive ? Icons.toggle_on : Icons.toggle_off, color: plan.isActive ? Colors.green : Colors.red, size: 20),
                    label: Text(plan.isActive ? 'Turn OFF' : 'Turn ON', style: TextStyle(color: plan.isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
            // Action Buttons
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Actions:', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showBasicInfoDialog(context, services, plan),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAdvancedSettingsDialog(context, services, plan),
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('Modify'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _deletePlan(plan),
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    Color color;
    switch (tier.toUpperCase()) {
      case 'GOLD':
        color = Colors.amber;
        break;
      case 'PLATINUM':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(tier, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Future<void> _togglePlanStatus(SubscriptionPlanModel plan) async {
    try {
      final client = Supabase.instance.client;
      await client.from('subscription_plans').update({'is_active': !plan.isActive}).eq('id', plan.id);
      ref.invalidate(streamAllSubscriptionPlansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan ${!plan.isActive ? 'activated' : 'deactivated'} successfully'), backgroundColor: !plan.isActive ? Colors.green : Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Failed to delete subscription');
      }
    }
  }

  void _deletePlan(SubscriptionPlanModel plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription?'),
        content: Text('Are you sure you want to delete "${plan.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                final client = Supabase.instance.client;
                await client.from('subscription_plans').delete().eq('id', plan.id);
                if (mounted) {
                  Navigator.pop(context);
                  ref.invalidate(streamAllSubscriptionPlansProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription deleted successfully'), backgroundColor: Colors.red));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  showErrorDialog(context, message: e.toString(), title: 'Delete Failed');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog(BuildContext context, List<StandardServiceModel> services, {SubscriptionPlanModel? existing}) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toInt().toString() ?? '');
    final originalPriceCtrl = TextEditingController(text: existing?.originalPrice?.toInt().toString() ?? '');
    final orderCtrl = TextEditingController(text: existing?.displayOrder.toString() ?? '0');

    String tier = existing?.tier ?? 'Silver';
    String vehicleCategory = existing?.vehicleCategory ?? 'Sedan';
    String duration = existing?.duration ?? 'Monthly';
    bool showUnlimited = existing?.showUnlimited ?? false;
    bool isFeatured = existing?.isFeatured ?? false;
    bool isActive = existing?.isActive ?? true;
    List<String> features = List<String>.from(existing?.features ?? []);
    List<String> includedServiceIds = List<String>.from(existing?.includedServiceIds ?? []);
    
    // Service usage limits - per service max uses per month
    Map<String, int> serviceUsageLimits = Map<String, int>.from(existing?.serviceUsageLimits ?? {});
    final serviceLimitCtrls = <String, TextEditingController>{};
    for (final serviceId in includedServiceIds) {
      serviceLimitCtrls[serviceId] = TextEditingController(
        text: serviceUsageLimits[serviceId]?.toString() ?? '',
      );
    }

    int _calculateTotalMonthly() {
      int total = 0;
      for (final entry in serviceLimitCtrls.entries) {
        final value = int.tryParse(entry.value.text) ?? 0;
        total += value;
      }
      return total;
    }

    final tierOptions = ['Silver', 'Gold', 'Platinum'];
    final vehicleOptions = ['Sedan', 'SUV', 'Compact'];
    final durationOptions = ['Monthly', 'Yearly'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(isEditing ? 'Edit Subscription' : 'Add New Subscription', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Plan Name'),
                        const SizedBox(height: 8),
                        _buildTextField(nameCtrl, 'e.g. Premium Wash'),
                        const SizedBox(height: 16),
                        _buildLabel('Description'),
                        const SizedBox(height: 8),
                        _buildTextField(descCtrl, 'Brief description', maxLines: 2),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Price (₹)'), const SizedBox(height: 8), _buildTextField(priceCtrl, '299', keyboardType: TextInputType.number)])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Original Price (₹)'), const SizedBox(height: 8), _buildTextField(originalPriceCtrl, '399', keyboardType: TextInputType.number)])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Tier'), const SizedBox(height: 8), _buildDropdown(tier, tierOptions, (v) => setModalState(() => tier = v ?? tier))])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Vehicle Category'), const SizedBox(height: 8), _buildDropdown(vehicleCategory, vehicleOptions, (v) => setModalState(() => vehicleCategory = v ?? vehicleCategory))])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Duration'), const SizedBox(height: 8), _buildDropdown(duration, durationOptions, (v) => setModalState(() => duration = v ?? duration))])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Display Order'), const SizedBox(height: 8), _buildTextField(orderCtrl, '0', keyboardType: TextInputType.number)])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Service Limits Section
                        _buildLabel('Service Limits (per month)'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            title: Text('${includedServiceIds.length} services selected', style: const TextStyle(fontSize: 14)),
                            children: services.map((s) {
                              final isSelected = includedServiceIds.contains(s.id);
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          includedServiceIds.add(s.id);
                                          serviceLimitCtrls[s.id] = TextEditingController();
                                        } else {
                                          includedServiceIds.remove(s.id);
                                          serviceLimitCtrls.remove(s.id);
                                          serviceUsageLimits.remove(s.id);
                                        }
                                      });
                                    },
                                    title: Text(s.name, style: const TextStyle(fontSize: 14)),
                                    subtitle: Text('₹${s.price.toInt()}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: serviceLimitCtrls[s.id],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: 'Max uses/month',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setModalState(() {}),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Total Monthly Display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Monthly Services:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              Text('${_calculateTotalMonthly()} services/month', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: PremiumTheme.orangePrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Daily Limit: 1 service per day (Fair Usage Policy)', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        // Included Services
                        // Features
                        _buildLabel('Features'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...features.map((f) => Chip(
                              label: Text(f, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setModalState(() => features.remove(f)),
                            )),
                            ActionChip(
                              label: const Text('+ Add Feature'),
                              onPressed: () => _showAddFeatureDialog(ctx, features, setModalState),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Toggles
                        Row(
                          children: [
                            Expanded(child: _buildToggle('Show Unlimited', showUnlimited, (v) => setModalState(() => showUnlimited = v))),
                            Expanded(child: _buildToggle('Is Featured', isFeatured, (v) => setModalState(() => isFeatured = v))),
                            Expanded(child: _buildToggle('Is Active', isActive, (v) => setModalState(() => isActive = v))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                          final originalPrice = double.tryParse(originalPriceCtrl.text.trim());
                          final order = int.tryParse(orderCtrl.text.trim()) ?? 0;

                          // Build service usage limits from controllers
                          final Map<String, int> limits = {};
                          for (final entry in serviceLimitCtrls.entries) {
                            final value = int.tryParse(entry.value.text);
                            if (value != null && value > 0) {
                              limits[entry.key] = value;
                            }
                          }

                          if (name.isEmpty || price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields'), backgroundColor: Colors.red));
                            return;
                          }

                          try {
                            final client = Supabase.instance.client;
                            final data = {
                              'name': name,
                              'description': descCtrl.text.trim(),
                              'price': price,
                              'original_price': originalPrice,
                              'tier': tier,
                              'vehicle_category': vehicleCategory,
                              'duration': duration,
                              'features': features,
                              'included_service_ids': includedServiceIds,
                              'show_unlimited': showUnlimited,
                              'is_featured': isFeatured,
                              'is_active': isActive,
                              'display_order': order,
                              'service_usage_limits': limits.isNotEmpty ? limits : null,
                              'daily_limit': 1,
                              'fair_usage_policy': '1 service per day. Unused services do not carry forward.',
                            };

                            if (isEditing) {
                              await client.from('subscription_plans').update(data).eq('id', existing.id);
                            } else {
                              await client.from('subscription_plans').insert(data);
                            }

                            if (mounted) {
                              Navigator.pop(ctx);
                              ref.invalidate(streamAllSubscriptionPlansProvider);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Subscription updated' : 'Subscription created'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) {
                              showErrorDialog(context, message: e.toString(), title: 'Save Failed');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0541E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(isEditing ? 'Update' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Basic Info Dialog - for Edit button
  void _showBasicInfoDialog(BuildContext context, List<StandardServiceModel> services, SubscriptionPlanModel plan) {
    final nameCtrl = TextEditingController(text: plan.name);
    final descCtrl = TextEditingController(text: plan.description ?? '');
    final priceCtrl = TextEditingController(text: plan.price.toInt().toString());
    final originalPriceCtrl = TextEditingController(text: plan.originalPrice?.toInt().toString() ?? '');

    String tier = plan.tier;
    String vehicleCategory = plan.vehicleCategory;
    String duration = plan.duration;

    final tierOptions = ['Silver', 'Gold', 'Platinum'];
    final vehicleOptions = ['Sedan', 'SUV', 'Compact'];
    final durationOptions = ['Monthly', 'Yearly'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Edit Basic Info', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Plan Name'),
                        const SizedBox(height: 8),
                        _buildTextField(nameCtrl, 'e.g. Premium Wash'),
                        const SizedBox(height: 16),
                        _buildLabel('Description'),
                        const SizedBox(height: 8),
                        _buildTextField(descCtrl, 'Brief description', maxLines: 2),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Price (₹)'), const SizedBox(height: 8), _buildTextField(priceCtrl, '299', keyboardType: TextInputType.number)])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Original Price (₹)'), const SizedBox(height: 8), _buildTextField(originalPriceCtrl, '399', keyboardType: TextInputType.number)])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Tier'), const SizedBox(height: 8), _buildDropdown(tier, tierOptions, (v) => setModalState(() => tier = v ?? tier))])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Vehicle Category'), const SizedBox(height: 8), _buildDropdown(vehicleCategory, vehicleOptions, (v) => setModalState(() => vehicleCategory = v ?? vehicleCategory))])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Duration'),
                        const SizedBox(height: 8),
                        _buildDropdown(duration, durationOptions, (v) => setModalState(() => duration = v ?? duration)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final client = Supabase.instance.client;
                            await client.from('subscription_plans').update({
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'price': int.tryParse(priceCtrl.text.trim()) ?? plan.price,
                              'original_price': int.tryParse(originalPriceCtrl.text.trim()),
                              'tier': tier,
                              'vehicle_category': vehicleCategory,
                              'duration': duration,
                            }).eq('id', plan.id);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ref.invalidate(streamAllSubscriptionPlansProvider);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Basic info updated!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) showErrorDialog(context, message: e.toString(), title: 'Update Failed');
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Advanced Settings Dialog - for Modify button
  void _showAdvancedSettingsDialog(BuildContext context, List<StandardServiceModel> services, SubscriptionPlanModel plan) {
    final orderCtrl = TextEditingController(text: plan.displayOrder.toString());

    bool showUnlimited = plan.showUnlimited;
    bool isFeatured = plan.isFeatured;
    bool isActive = plan.isActive;
    List<String> features = List<String>.from(plan.features ?? []);
    List<String> includedServiceIds = List<String>.from(plan.includedServiceIds ?? []);
    Map<String, int> serviceUsageLimits = Map<String, int>.from(plan.serviceUsageLimits ?? {});

    final serviceLimitCtrls = <String, TextEditingController>{};
    for (final serviceId in includedServiceIds) {
      serviceLimitCtrls[serviceId] = TextEditingController(
        text: serviceUsageLimits[serviceId]?.toString() ?? '',
      );
    }

    int _calculateTotalMonthly() {
      int total = 0;
      for (final entry in serviceLimitCtrls.entries) {
        final value = int.tryParse(entry.value.text) ?? 0;
        total += value;
      }
      return total;
    }

    final featureOptions = ['Free Vacuum', 'Free Tire Shine', 'Free Interior Detailing', 'Priority Booking', 'Free Polish', 'Free Wax', 'Free Coating', 'Custom'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Modify Advanced Settings', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Limits Section - NEW UI
                        _buildLabel('Service Limits (per month)'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            title: Text('${includedServiceIds.length} services selected', style: const TextStyle(fontSize: 14)),
                            children: services.map((s) {
                              final isSelected = includedServiceIds.contains(s.id);
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          includedServiceIds.add(s.id);
                                          serviceLimitCtrls[s.id] = TextEditingController();
                                        } else {
                                          includedServiceIds.remove(s.id);
                                          serviceLimitCtrls.remove(s.id);
                                          serviceUsageLimits.remove(s.id);
                                        }
                                      });
                                    },
                                    title: Text(s.name, style: const TextStyle(fontSize: 14)),
                                    subtitle: Text('₹${s.price.toInt()}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: serviceLimitCtrls[s.id],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: 'Max uses/month',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setModalState(() {}),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Total Monthly Display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Monthly Services:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              Text('${_calculateTotalMonthly()} services/month', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: PremiumTheme.orangePrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Daily Limit: 1 service per day (Fair Usage Policy)', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        // Display Order
                        _buildLabel('Display Order'),
                        const SizedBox(height: 8),
                        _buildTextField(orderCtrl, '0', keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        // Features
                        _buildLabel('Features'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...features.map((f) => Chip(
                              label: Text(f, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setModalState(() => features.remove(f)),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Toggles
                        Row(
                          children: [
                            Expanded(child: _buildToggle('Show Unlimited', showUnlimited, (v) => setModalState(() => showUnlimited = v))),
                            Expanded(child: _buildToggle('Is Featured', isFeatured, (v) => setModalState(() => isFeatured = v))),
                            Expanded(child: _buildToggle('Is Active', isActive, (v) => setModalState(() => isActive = v))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Build service usage limits from controllers
                            final Map<String, int> limits = {};
                            for (final entry in serviceLimitCtrls.entries) {
                              final value = int.tryParse(entry.value.text);
                              if (value != null && value > 0) {
                                limits[entry.key] = value;
                              }
                            }

                            final client = Supabase.instance.client;
                            await client.from('subscription_plans').update({
                              'display_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                              'features': features,
                              'show_unlimited': showUnlimited,
                              'is_featured': isFeatured,
                              'is_active': isActive,
                              'service_usage_limits': limits.isNotEmpty ? limits : null,
                              'daily_limit': 1,
                              'fair_usage_policy': '1 service per day. Unused services do not carry forward.',
                            }).eq('id', plan.id);
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              ref.invalidate(streamAllSubscriptionPlansProvider);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) showErrorDialog(context, message: e.toString(), title: 'Update Failed');
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFFF0541E)),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _showAddFeatureDialog(BuildContext ctx, List<String> features, StateSetter setModalState) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Feature'),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'e.g. Free Vacuum', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setModalState(() => features.add(ctrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF0541E))),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

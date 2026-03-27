import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../application/providers/standard_service_providers.dart';
import '../../../application/providers/standard_service_stream_providers.dart';
import '../../../domain/models/standard_service_model.dart';
import '../../../theme/app_theme.dart';

class AdminStandardServicesScreen extends ConsumerStatefulWidget {
  const AdminStandardServicesScreen({super.key});

  @override
  ConsumerState<AdminStandardServicesScreen> createState() =>
      _AdminStandardServicesScreenState();
}

class _AdminStandardServicesScreenState
    extends ConsumerState<AdminStandardServicesScreen> {
  String _filterCategory = 'All';

  @override
  Widget build(BuildContext context) {
    // Use realtime stream provider so admin sees live changes
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
              child: const Icon(
                Icons.local_car_wash_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'One-Time Services',
              style: GoogleFonts.inter(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showServiceDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF0541E),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: servicesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF0541E)),
          ),
          error: (err, _) {
          final isTableError = err.toString().contains('PGRST116') || err.toString().contains('standard_services');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Error Loading Services',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isTableError
                      ? 'The standard_services table was not found.\nMigration: 20240220_create_standard_services.sql'
                      : 'Error: $err',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(streamAllStandardServicesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        data: (services) => _buildBody(services),
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

  Widget _buildBody(List<StandardServiceModel> services) {
    // Get unique categories
    final categories = [
      'All',
      ...{...services.map((s) => s.category)},
    ];

    // Filter
    final filtered = _filterCategory == 'All'
        ? services
        : services.where((s) => s.category == _filterCategory).toList();

    return Column(
      children: [
        // Category filter chips
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _filterCategory == cat;
              return FilterChip(
                selected: isSelected,
                label: Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.grey[300]!,
                  ),
                ),
                onSelected: (_) => setState(() => _filterCategory = cat),
              );
            },
          ),
        ),

        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildStatChip(
                '${services.length} Total',
                Icons.dashboard_rounded,
                const Color(0xFF667EEA),
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '${services.where((s) => s.isActive).length} Active',
                Icons.check_circle_rounded,
                const Color(0xFF22C55E),
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '${services.where((s) => !s.isActive).length} Hidden',
                Icons.visibility_off_rounded,
                Colors.grey,
              ),
            ],
          ),
        ),

        // Service list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildServiceTile(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(StandardServiceModel service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Service Info + Price + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${service.category} • One-Time Service',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Price + Status Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${service.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color(0xFFE85A10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(service.isActive ? 'Active' : 'Inactive'),
                      backgroundColor: service.isActive
                          ? Colors.green[100]
                          : Colors.red[100],
                      labelStyle: TextStyle(
                        color: service.isActive
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Description
            const SizedBox(height: 12),
            Text(
              'Description:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              service.description,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // ON/OFF Toggle Button
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Availability:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleServiceStatus(service),
                  icon: Icon(
                    service.isActive ? Icons.toggle_on : Icons.toggle_off,
                    color: service.isActive ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  label: Text(
                    service.isActive ? 'Turn OFF' : 'Turn ON',
                    style: TextStyle(
                      color: service.isActive ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            // Action Buttons (Edit, Modify, Delete)
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Actions:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // EDIT Button
                      ElevatedButton.icon(
                        onPressed: () => _showServiceDialog(context, existing: service),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // MODIFY Button (Edit)
                      ElevatedButton.icon(
                        onPressed: () => _showServiceDialog(context, existing: service),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Modify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // DELETE Button
                      ElevatedButton.icon(
                        onPressed: () => _deleteService(service),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Remove'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleServiceStatus(StandardServiceModel service) async {
    try {
      final repo = ref.read(standardServiceRepoProvider);
      
      // Update in Supabase
      await repo.toggleActive(service.id, !service.isActive);
      
      // Invalidate StreamProvider to refresh realtime stream
      ref.invalidate(streamAllStandardServicesProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Service ${!service.isActive ? 'activated' : 'deactivated'} successfully - Live updating...',
            ),
            backgroundColor: !service.isActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    }
  }

  void _deleteService(StandardServiceModel service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service?'),
        content: Text(
          'This will remove "${service.name}" from available services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final repo = ref.read(standardServiceRepoProvider);
                await repo.deleteService(service.id);
                if (mounted) {
                  Navigator.pop(context);
                  ref.invalidate(streamAllStandardServicesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service deleted successfully - Live updating...'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showServiceDialog(
    BuildContext context, {
    StandardServiceModel? existing,
  }) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toInt().toString() : '',
    );
    final orderCtrl = TextEditingController(
      text: existing?.displayOrder.toString() ?? '0',
    );
    String category = existing?.category ?? 'Washing';
    bool isActive = existing?.isActive ?? true;

    final availableCategories = [
      'Washing',
      'Dry Cleaning',
      'Rubbing & Polish',
      'Protection',
      'Detailing',
      'Specialty',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    isEditing ? 'Edit Service' : 'Add New Service',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Service Name
                  _buildLabel('Service Name'),
                  const SizedBox(height: 8),
                  _buildTextField(nameCtrl, 'e.g. Exterior Wash'),

                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    descCtrl,
                    'Brief description of the service',
                    maxLines: 2,
                  ),

                  const SizedBox(height: 16),

                  // Price + Order Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Price (₹)'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              priceCtrl,
                              '199',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Order'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              orderCtrl,
                              '1',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Category
                  _buildLabel('Category'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: availableCategories.contains(category)
                            ? category
                            : availableCategories.first,
                        isExpanded: true,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        items: availableCategories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => category = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Active toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Visible to Customers',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        isActive ? 'Service is live' : 'Service is hidden',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      value: isActive,
                      activeThumbColor: const Color(0xFF22C55E),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => isActive = val),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _saveService(
                        ctx,
                        existing: existing,
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text) ?? 0,
                        category: category,
                        displayOrder: int.tryParse(orderCtrl.text) ?? 0,
                        isActive: isActive,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0541E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Update Service' : 'Create Service',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.grey[400],
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0541E), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _saveService(
    BuildContext ctx, {
    StandardServiceModel? existing,
    required String name,
    required String description,
    required double price,
    required String category,
    required int displayOrder,
    required bool isActive,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service name is required'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final service = StandardServiceModel(
      id: existing?.id ?? '',
      name: name,
      description: description,
      price: price,
      category: category,
      displayOrder: displayOrder,
      isActive: isActive,
      imageUrl: existing?.imageUrl,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    try {
      await ref.read(standardServiceRepoProvider).upsertService(service);
      ref.invalidate(streamAllStandardServicesProvider);

      if (ctx.mounted) Navigator.pop(ctx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing != null
                  ? '$name updated successfully - Live updating...'
                  : '$name created successfully - Live updating...',
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_rounded, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            'No Services Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the "Add" button to create your first service.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Unused helper methods - kept for reference if needed in future
  /*
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Washing':
        return Icons.water_drop_rounded;
      case 'Dry Cleaning':
        return Icons.dry_cleaning_rounded;
      case 'Rubbing & Polish':
        return Icons.auto_awesome_rounded;
      case 'Protection':
        return Icons.shield_rounded;
      case 'Detailing':
        return Icons.brush_rounded;
      case 'Specialty':
        return Icons.star_rounded;
      default:
        return Icons.local_car_wash_rounded;
    }
  }
  */

  /*
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Washing':
        return const Color(0xFF4FACFE);
      case 'Dry Cleaning':
        return const Color(0xFFF5576C);
      case 'Rubbing & Polish':
        return const Color(0xFFD4AF37);
      case 'Protection':
        return const Color(0xFF43E97B);
      case 'Detailing':
        return const Color(0xFF764BA2);
      case 'Specialty':
        return const Color(0xFFF0541E);
      default:
        return Colors.grey;
    }
  }
  */
}

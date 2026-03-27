import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../application/providers/feature_providers.dart';
import '../../../domain/models/service_pricing_model.dart';

class AdminServicePricingManagementScreen extends ConsumerStatefulWidget {
  const AdminServicePricingManagementScreen({super.key});

  @override
  ConsumerState<AdminServicePricingManagementScreen> createState() =>
      _AdminServicePricingManagementScreenState();
}

class _AdminServicePricingManagementScreenState
    extends ConsumerState<AdminServicePricingManagementScreen> {
  final String _filterCategory = 'All';
  // final bool _showInactive = false; // Unused
  final List<String> _categories = [
    'All',
    'Washing',
    'Cleaning',
    'Detailing',
    'Protection',
    'Treatment',
    'Restoration',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'One-Time Services',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddServiceDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0541E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _filterCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            // Update filter logic here
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildServiceList()),
      ],
    );
  }

  Widget _buildServiceList() {
    // Show all one-time services from service_pricing table
    final servicesAsync = ref.watch(oneTimeServicesProvider);

    return servicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF0541E),
          strokeWidth: 3,
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Error loading services',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (allServices) {
        if (allServices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_car_wash_rounded,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No one-time services found',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allServices.length,
          itemBuilder: (context, index) {
            final service = allServices[index];
            return _buildServiceCard(service);
          },
        );
      },
    );
  }

  Widget _buildServiceCard(ServicePricingModel service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        service.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0541E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.category,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF0541E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${service.price.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: const Color(0xFFF0541E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(
                        service.isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: service.isActive
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                      backgroundColor: service.isActive
                          ? Colors.green[50]
                          : Colors.red[50],
                      side: BorderSide(
                        color: service.isActive
                            ? Colors.green[200]!
                            : Colors.red[200]!,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
              ],
            ),
            if (service.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                service.description,
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditServiceDialog(service),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteService(service.id),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => const _ServiceFormDialog(),
    );
  }

  void _showEditServiceDialog(ServicePricingModel service) {
    showDialog(
      context: context,
      builder: (context) => _ServiceFormDialog(service: service),
    );
  }

  void _deleteService(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(adminOpsRepositoryProvider).deleteService(id);
                if (mounted) {
                  Navigator.pop(context);
                  // Invalidate the provider to refresh the list
                  // ignore: unused_result
                  ref.invalidate(oneTimeServicesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Service deleted successfully'),
                      backgroundColor: Colors.green[600],
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
}

class _ServiceFormDialog extends ConsumerStatefulWidget {
  final ServicePricingModel? service;

  const _ServiceFormDialog({this.service});

  @override
  ConsumerState<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<_ServiceFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _categoryController = TextEditingController(
      text: widget.service?.category ?? 'Washing',
    );
    _priceController = TextEditingController(
      text: widget.service?.price.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.service?.description ?? '',
    );
    _isActive = widget.service?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.service == null ? 'Add One-Time Service' : 'Edit Service',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField('Service Name', _nameController),
            const SizedBox(height: 16),
            _buildDropdown(
              'Category',
              _categoryController.text,
              [
                'Washing',
                'Cleaning',
                'Detailing',
                'Protection',
                'Treatment',
                'Restoration',
              ],
              (value) => setState(() => _categoryController.text = value!),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Price (₹)',
              _priceController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField('Description', _descriptionController, maxLines: 3),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              tileColor: Colors.grey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF0541E),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: maxLines == 1 ? 1 : null,
          enabled: !_isLoading,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: _isLoading ? null : onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a service name')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a price')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final price = double.parse(_priceController.text);

      final service = ServicePricingModel(
        id: widget.service?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        price: price,
        isActive: _isActive,
      );

      if (widget.service == null) {
        // Create new service
        await ref.read(adminOpsRepositoryProvider).createService(service);
      } else {
        // Update existing service
        await ref.read(adminOpsRepositoryProvider).updateService(service);
      }

      if (mounted) {
        Navigator.pop(context);
        // Invalidate stream to refresh
        // ignore: unused_result
        ref.invalidate(oneTimeServicesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.service == null
                  ? '✅ Service created successfully'
                  : '✅ Service updated successfully',
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    }
  }
}

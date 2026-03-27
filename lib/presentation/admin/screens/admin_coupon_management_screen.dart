import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../domain/models/coupon_model.dart';
import '../../../theme/app_theme.dart';

/// Admin Coupon Management Screen
/// Allows admin to: create, edit, delete, and manage coupon codes
class AdminCouponManagementScreen extends StatefulWidget {
  const AdminCouponManagementScreen({super.key});

  @override
  State<AdminCouponManagementScreen> createState() =>
      _AdminCouponManagementScreenState();
}

class _AdminCouponManagementScreenState
    extends State<AdminCouponManagementScreen> {
  // TODO: Fetch coupons from Supabase
  final List<CouponModel> coupons = [
    CouponModel(
      id: '1',
      code: 'DRIVE2024',
      description: 'New Year Special - 10% off all subscriptions',
      type: CouponType.percentage,
      value: 10,
      minPurchaseAmount: 0,
      maxDiscountAmount: null,
      usageLimit: -1,
      usageCount: 145,
      validFrom: DateTime.now().subtract(const Duration(days: 30)),
      validUntil: DateTime.now().add(const Duration(days: 60)),
      applicablePlans: [],
      status: CouponStatus.active,
      notes: 'Valid for all plans',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    ),
    CouponModel(
      id: '2',
      code: 'WELCOME500',
      description: 'Welcome bonus - ₹500 off premium services',
      type: CouponType.fixedAmount,
      value: 500,
      minPurchaseAmount: 2000,
      maxDiscountAmount: 500,
      usageLimit: 0,
      usageCount: 0,
      validFrom: DateTime.now().add(const Duration(days: 10)),
      validUntil: DateTime.now().add(const Duration(days: 40)),
      applicablePlans: [],
      status: CouponStatus.inactive,
      notes: 'For new customers only',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Coupon Management',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateCouponDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'New Coupon',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.orangePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: coupons.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              itemBuilder: (context, index) {
                final coupon = coupons[index];
                return _buildCouponCard(context, coupon);
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

  /// Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'No Coupons Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first coupon to start offering discounts',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCreateCouponDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Coupon'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.orangePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Coupon Card
  Widget _buildCouponCard(BuildContext context, CouponModel coupon) {
    final isExpired = coupon.validUntil.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? Colors.red[200]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with code and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: PremiumTheme.orangePrimary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        coupon.code,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: PremiumTheme.orangePrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coupon.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    coupon.status.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: _getStatusColor(coupon.status),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Discount & Validity Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoColumn(
                    label: 'Discount',
                    value: coupon.type == CouponType.percentage
                        ? '${coupon.value}%'
                        : '₹${coupon.value.toInt()}',
                  ),
                ),
                Expanded(
                  child: _buildInfoColumn(
                    label: 'Usage',
                    value: coupon.usageLimit == -1
                        ? '${coupon.usageCount} uses'
                        : '${coupon.usageCount}/${coupon.usageLimit}',
                  ),
                ),
                Expanded(
                  child: _buildInfoColumn(
                    label: 'Valid Until',
                    value: _formatDate(coupon.validUntil),
                  ),
                ),
              ],
            ),

            // Expiration indicator if expired
            if (isExpired)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 16, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Coupon expired',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditCouponDialog(context, coupon),
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context, coupon.code),
                  icon: const Icon(Icons.delete, size: 18),
                  label: Text(
                    'Delete',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Info Column Helper
  Widget _buildInfoColumn({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // Dialog Handlers
  void _showCreateCouponDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CouponFormDialog(
        onSave: (code, description, type, value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon "$code" created successfully')),
          );
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showEditCouponDialog(BuildContext context, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (context) => _CouponFormDialog(
        initialCode: coupon.code,
        initialDescription: coupon.description,
        onSave: (code, description, type, value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon updated successfully')),
          );
          Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coupon?'),
        content: Text('Are you sure you want to delete coupon "$code"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Coupon "$code" deleted')),
              );
              setState(() {
                coupons.removeWhere((c) => c.code == code);
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helpers
  Color _getStatusColor(CouponStatus status) {
    switch (status) {
      case CouponStatus.active:
        return Colors.green[600]!;
      case CouponStatus.inactive:
        return Colors.grey[400]!;
      case CouponStatus.expired:
        return Colors.red[600]!;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Coupon Form Dialog
class _CouponFormDialog extends StatefulWidget {
  final String? initialCode;
  final String? initialDescription;
  final Function(String code, String description, CouponType type, double value)
      onSave;

  const _CouponFormDialog({
    this.initialCode,
    this.initialDescription,
    required this.onSave,
  });

  @override
  State<_CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<_CouponFormDialog> {
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  late TextEditingController _valueController;
  late TextEditingController _minPurchaseController;
  late TextEditingController _maxDiscountController;
  CouponType _selectedType = CouponType.percentage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _valueController = TextEditingController();
    _minPurchaseController = TextEditingController();
    _maxDiscountController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialCode != null ? 'Edit Coupon' : 'Create New Coupon',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coupon Code
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Coupon Code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Coupon Type
            DropdownButtonFormField<CouponType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Discount Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: CouponType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name == 'percentage'
                            ? 'Percentage (%)'
                            : 'Fixed Amount (₹)'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),

            // Value
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _selectedType == CouponType.percentage
                    ? 'Percentage Value'
                    : 'Discount Amount (₹)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Min Purchase Amount
            TextField(
              controller: _minPurchaseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Min Purchase Amount (₹)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Max Discount Amount
            if (_selectedType == CouponType.percentage)
              TextField(
                controller: _maxDiscountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Max Discount Amount (₹) - Optional',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_codeController.text.isEmpty ||
                _descriptionController.text.isEmpty ||
                _valueController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all required fields')),
              );
              return;
            }

            widget.onSave(
              _codeController.text,
              _descriptionController.text,
              _selectedType,
              double.parse(_valueController.text),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumTheme.orangePrimary,
          ),
          child: Text(
            widget.initialCode != null ? 'Update' : 'Create',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

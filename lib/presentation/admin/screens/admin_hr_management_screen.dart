import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../application/helpers/error_helper.dart';

class AdminHRManagementScreen extends ConsumerStatefulWidget {
  const AdminHRManagementScreen({super.key});

  @override
  ConsumerState<AdminHRManagementScreen> createState() => _AdminHRManagementScreenState();
}

class _AdminHRManagementScreenState extends ConsumerState<AdminHRManagementScreen> {
  final _client = Supabase.instance.client;
  
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoading = true;
  String _filterCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      // Use OLD system - user_profiles table
      final result = await _client
          .from('user_profiles')
          .select('''
            id,
            full_name,
            phone,
            membership_tier,
            employee_id,
            username,
            created_at,
            updated_at
          ''')
          .order('created_at', ascending: false);
      
      setState(() {
        _staffList = List<Map<String, dynamic>>.from(result);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorDialog(context, message: e.toString(), title: 'Failed to Load Staff');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStaff {
    var filtered = _staffList;
    
    if (_filterCategory != 'All') {
      filtered = filtered.where((s) => s['membership_tier'] == _filterCategory).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final profile = s['staff_profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString().toLowerCase() ?? '';
        final employeeId = s['employee_id']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || employeeId.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF0541E)))
                : _filteredStaff.isEmpty
                    ? _buildEmptyState()
                    : _buildStaffList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(),
        backgroundColor: const Color(0xFFF0541E),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('Add Staff', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            child: const Icon(Icons.people_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'HR Management',
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search staff...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterCategory,
                items: ['All', 'ADMIN', 'MANAGER', 'SUPERVISOR', 'WASHER', 'FRONT_DESK']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _filterCategory = v ?? 'All'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No staff members found', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddStaffDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Staff'),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return RefreshIndicator(
      onRefresh: _loadStaff,
      color: const Color(0xFFF0541E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredStaff.length,
        itemBuilder: (context, index) => _buildStaffCard(_filteredStaff[index]),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final profile = staff['staff_profiles'] as Map<String, dynamic>?;
    final fullName = profile?['full_name'] ?? 'No Name';
    final phone = profile?['phone'] ?? '';
    final department = profile?['department'] ?? '';
    final isActive = staff['is_active'] as bool? ?? true;
    final mustChangePassword = staff['must_change_password'] as bool? ?? true;
    final failedAttempts = staff['failed_login_attempts'] as int? ?? 0;
    final lastLogin = staff['last_login_at'] != null 
        ? DateTime.tryParse(staff['last_login_at'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showStaffDetailsDialog(staff),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFF0541E).withValues(alpha: 0.1),
                    child: Text(
                      fullName.toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Color(0xFFF0541E), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.toString(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          '${staff['employee_id']} • ${staff['staff_category']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isActive, mustChangePassword),
                ],
              ),
              if (phone.isNotEmpty || department.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 16),
                    ],
                    if (department.isNotEmpty) ...[
                      Icon(Icons.business, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(department, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ],
                ),
              ],
              if (lastLogin != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last login: ${_formatDate(lastLogin)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
              if (failedAttempts > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, size: 12, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        '$failedAttempts failed attempts',
                        style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditStaffDialog(staff),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  TextButton.icon(
                    onPressed: () => _showResetPasswordDialog(staff),
                    icon: const Icon(Icons.lock_reset, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  TextButton.icon(
                    onPressed: () => _toggleStaffStatus(staff),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    label: Text(isActive ? 'Deactivate' : 'Activate'),
                    style: TextButton.styleFrom(
                      foregroundColor: isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, bool mustChangePassword) {
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
        child: Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w600)),
      );
    }
    if (mustChangePassword) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
        child: Text('PWD Reset', style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)),
      child: Text('Active', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddStaffDialog() {
    _showStaffFormDialog(null);
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    _showStaffFormDialog(staff);
  }

  void _showStaffFormDialog(Map<String, dynamic>? staff) {
    final isEditing = staff != null;
    final profile = staff?['staff_profiles'] as Map<String, dynamic>?;
    
    final employeeIdCtrl = TextEditingController(text: staff?['employee_id'] ?? '');
    final usernameCtrl = TextEditingController(text: staff?['username'] ?? '');
    final nameCtrl = TextEditingController(text: profile?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: profile?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: profile?['email'] ?? '');
    final departmentCtrl = TextEditingController(text: profile?['department'] ?? '');
    final designationCtrl = TextEditingController(text: profile?['designation'] ?? '');
    
    String category = staff?['staff_category'] ?? 'WASHER';

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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(isEditing ? 'Edit Staff' : 'Add New Staff', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildFormField('Employee ID *', employeeIdCtrl, 'e.g. EMP001'),
                        const SizedBox(height: 16),
                        _buildFormField('Username', usernameCtrl, 'Optional'),
                        const SizedBox(height: 16),
                        _buildFormField('Full Name *', nameCtrl, 'Full name'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Phone', phoneCtrl, 'Phone number')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFormField('Email', emailCtrl, 'Email address')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFormField('Department', departmentCtrl, 'e.g. Operations')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFormField('Designation', designationCtrl, 'e.g. Senior')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField('Staff Category', category, ['ADMIN', 'MANAGER', 'SUPERVISOR', 'WASHER', 'FRONT_DESK'], (v) => setModalState(() => category = v ?? category)),
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
                          if (employeeIdCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields')));
                            return;
                          }
                          
                          try {
                            if (isEditing) {
                              await _client.from('staff_auth').update({
                                'employee_id': employeeIdCtrl.text.trim(),
                                'username': usernameCtrl.text.trim().isEmpty ? null : usernameCtrl.text.trim(),
                                'staff_category': category,
                                'updated_at': DateTime.now().toIso8601String(),
                              }).eq('id', staff['id']);
                              
                              await _client.from('staff_profiles').update({
                                'full_name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                'department': departmentCtrl.text.trim().isEmpty ? null : departmentCtrl.text.trim(),
                                'designation': designationCtrl.text.trim().isEmpty ? null : designationCtrl.text.trim(),
                              }).eq('id', staff['id']);
                            } else {
                              final tempPassword = 'Welcome123';
                              
                              final authResult = await _client.from('staff_auth').insert({
                                'employee_id': employeeIdCtrl.text.trim(),
                                'username': usernameCtrl.text.trim().isEmpty ? null : usernameCtrl.text.trim(),
                                'password_hash': 'TEMP_${tempPassword}',  // Will need admin to set
                                'staff_category': category,
                                'must_change_password': true,
                                'is_active': true,
                              }).select().single();
                              
                              await _client.from('staff_profiles').insert({
                                'id': authResult['id'],
                                'full_name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                'department': departmentCtrl.text.trim().isEmpty ? null : departmentCtrl.text.trim(),
                                'designation': designationCtrl.text.trim().isEmpty ? null : designationCtrl.text.trim(),
                              });
                            }
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadStaff();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Staff updated' : 'Staff added'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) {
                              showErrorDialog(context, message: e.toString(), title: 'Failed to Save Staff');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0541E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(isEditing ? 'Update' : 'Add Staff'),
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

  Widget _buildFormField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(value: value, isExpanded: true, items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> staff) {
    final profile = staff['staff_profiles'] as Map<String, dynamic>?;
    final newPasswordCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset password for ${profile?['full_name'] ?? staff['employee_id']}?'),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'Enter new password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Staff will be forced to change password on next login', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a password')));
                return;
              }
              
              try {
                await _client.rpc('admin_reset_staff_password', params: {
                  'p_admin_id': _client.auth.currentUser?.id,
                  'p_staff_id': staff['id'],
                  'p_new_password': newPasswordCtrl.text.trim(),
                });
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadStaff();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  showErrorDialog(context, message: e.toString(), title: 'Password Reset Failed');
                }
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _toggleStaffStatus(Map<String, dynamic> staff) async {
    final isActive = staff['is_active'] as bool? ?? true;
    final newStatus = !isActive;
    
    try {
      await _client.from('staff_auth').update({
        'is_active': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', staff['id']);
      
      _loadStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Staff activated' : 'Staff deactivated'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    }
  }

  void _showStaffDetailsDialog(Map<String, dynamic> staff) {
    final profile = staff['staff_profiles'] as Map<String, dynamic>?;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Staff Details', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDetailRow('Employee ID', staff['employee_id']),
                      _buildDetailRow('Username', staff['username'] ?? 'N/A'),
                      _buildDetailRow('Full Name', profile?['full_name'] ?? 'N/A'),
                      _buildDetailRow('Phone', profile?['phone'] ?? 'N/A'),
                      _buildDetailRow('Email', profile?['email'] ?? 'N/A'),
                      _buildDetailRow('Department', profile?['department'] ?? 'N/A'),
                      _buildDetailRow('Designation', profile?['designation'] ?? 'N/A'),
                      _buildDetailRow('Category', staff['staff_category']),
                      _buildDetailRow('Status', staff['is_active'] == true ? 'Active' : 'Inactive'),
                      _buildDetailRow('Must Change Password', staff['must_change_password'] == true ? 'Yes' : 'No'),
                      _buildDetailRow('Failed Login Attempts', '${staff['failed_login_attempts'] ?? 0}'),
                      _buildDetailRow('Created At', staff['created_at']?.toString() ?? 'N/A'),
                      _buildDetailRow('Last Login', staff['last_login_at']?.toString() ?? 'Never'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

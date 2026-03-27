import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../theme/app_theme.dart';

class AdminStaffManagementScreen extends StatefulWidget {
  const AdminStaffManagementScreen({super.key});

  @override
  State<AdminStaffManagementScreen> createState() =>
      _AdminStaffManagementScreenState();
}

class _AdminStaffManagementScreenState
    extends State<AdminStaffManagementScreen> {
  final _client = Supabase.instance.client;
  static const _supabaseUrl = 'https://fqgifkijuykxkusxoeqe.supabase.co';
  static const _supabaseAnonKey =
      'sb_publishable_z0O1Te1Hv7w7PwqHISiOMQ_hKoBBSt2';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();

  bool _loading = true;
  bool _creating = false;
  bool _updating = false;
  String? _error;
  bool _isAdmin = false;
  String _selectedRole = 'WASHER';

  List<Map<String, dynamic>> _staffRows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Admin login required.');
      }

      final isAdmin = await _resolveIsAdmin(currentUser);

      // Use user_profiles only (no more staff_users)
      final profileResponse = await _client
          .from('user_profiles')
          .select('id, full_name, phone, membership_tier, employee_id, username, created_at, updated_at');

      final allProfiles = (profileResponse as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      
      // Filter for staff/admin
      final profileRows = allProfiles.where((p) => 
        (p['membership_tier'] as String?)?.toUpperCase() == 'STAFF' ||
        (p['membership_tier'] as String?)?.toUpperCase() == 'ADMIN'
      ).toList();

      // Map to staff format for compatibility
      final staffRows = profileRows.map((p) => {
        'id': p['id'],
        'employee_id': p['employee_id'] ?? p['username'] ?? '',
        'role_key': p['membership_tier'],
        'is_active': true,
        'created_at': p['created_at'],
        'updated_at': p['updated_at'],
        'full_name': p['full_name'],
        'phone': p['phone'],
      }).toList();

      // Now staffRows contains all staff/admin data - simplify the merge
      final merged = <Map<String, dynamic>>[];
      for (final staff in staffRows) {
        merged.add({
          'id': staff['id'],
          'full_name': staff['full_name'] ?? 'Staff',
          'phone': staff['phone'],
          'membership_tier': (staff['role_key'] ?? 'STAFF').toString().toUpperCase(),
          'created_at': staff['created_at'],
          'employee_id': staff['employee_id'],
          'role_key': staff['role_key'] ?? 'WASHER',
          'is_active': true,
        });
      }

      merged.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _staffRows = merged;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _resolveIsAdmin(User currentUser) async {
    // Primary source of truth: backend role helper.
    try {
      final rpcResult = await _client.rpc('is_admin_user');
      if (rpcResult is bool) return rpcResult;
      if (rpcResult is num) return rpcResult != 0;
      if (rpcResult is String) return rpcResult.toLowerCase() == 'true';
    } catch (_) {
      // Fall through to local checks.
    }

    // Fallback checks for environments where RPC is not available yet.
    try {
      final me = await _client
          .from('user_profiles')
          .select('membership_tier')
          .eq('id', currentUser.id)
          .maybeSingle();
      final profileTier = ((me?['membership_tier'] ?? 'FREE').toString())
          .toUpperCase();
      if (profileTier == 'ADMIN') return true;
    } catch (_) {}

    final metadataTier =
        ((currentUser.userMetadata?['membership_tier'] ?? '').toString())
            .toUpperCase();
    final email = (currentUser.email ?? '').trim().toLowerCase();
    return metadataTier == 'ADMIN' || email == 'admin@gmail.com';
  }

  Future<void> _createStaffCredential() async {
    if (!_isAdmin) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final employeeId = _employeeIdController.text.trim();

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter name, email and password (min 6 chars).'),
        ),
      );
      return;
    }

    setState(() => _creating = true);

    String? adminRefreshToken;
    SupabaseClient? tempClient;
    try {
      adminRefreshToken = _client.auth.currentSession?.refreshToken;
      if (adminRefreshToken == null) {
        throw Exception('Admin session expired. Please login again.');
      }

      tempClient = SupabaseClient(
        _supabaseUrl,
        _supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );

      await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'membership_tier': 'STAFF'},
      );

      await _promoteExistingUserToStaff(
        email: email,
        fullName: name,
        phone: phone,
        role: _selectedRole,
        employeeId: employeeId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff credential created successfully.')),
      );
      _clearCreateForm();
      await _load();
    } on AuthApiException catch (e) {
      if (e.code == 'user_already_exists') {
        try {
          await _promoteExistingUserToStaff(
            email: email,
            fullName: name,
            phone: phone,
            role: _selectedRole,
            employeeId: employeeId,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Existing account promoted to STAFF.'),
            ),
          );
          await _load();
        } catch (rpcError) {
          if (!mounted) return;
          showErrorDialog(context, message: rpcError.toString(), title: 'Staff Creation Failed');
        }
      } else {
        if (!mounted) return;
        showErrorDialog(context, message: e.message.toString(), title: 'Staff Creation Failed');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (tempClient != null) {
        try {
          await tempClient.auth.signOut();
        } catch (_) {}
      }
      if (adminRefreshToken != null) {
        try {
          await _client.auth.setSession(adminRefreshToken);
        } catch (_) {}
      }
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _promoteExistingUserToStaff({
    required String email,
    required String fullName,
    required String phone,
    required String role,
    required String employeeId,
  }) async {
    await _client.rpc(
      'promote_existing_user_to_staff',
      params: {
        'p_email': email,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_role': role,
        'p_employee_id': employeeId,
      },
    );
  }

  Future<void> _updateStaff({
    required String userId,
    required String fullName,
    required String phone,
    required String role,
    required bool isActive,
    required String membershipTier,
    String? employeeId,
  }) async {
    if (!_isAdmin) return;
    setState(() => _updating = true);
    try {
      // Try RPC first, fallback to direct update
      try {
        await _client.rpc(
          'admin_update_staff_account',
          params: {
            'p_staff_user_id': userId,
            'p_full_name': fullName,
            'p_phone': phone,
            'p_role': role,
            'p_is_active': isActive,
          },
        );
      } catch (rpcError) {
        // Fallback to direct update via RLS
        await _client
            .from('user_profiles')
            .update({
              'full_name': fullName,
              'phone': phone,
              'membership_tier': role == 'ADMIN' ? 'ADMIN' : 'STAFF',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      }

      // Update employee_id if provided (use user_profiles)
      if (employeeId != null && employeeId.isNotEmpty) {
        await _client
            .from('user_profiles')
            .update({'employee_id': employeeId, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff details updated.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _removeStaff(String userId) async {
    if (!_isAdmin) return;
    setState(() => _updating = true);
    try {
      await _client
          .from('user_profiles')
          .update({'membership_tier': 'FREE'})
          .eq('id', userId);
      // No need to update staff_users since we removed it
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff access removed.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _resetStaffPassword(String userId, String staffName) async {
    if (!_isAdmin) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to $staffName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updating = true);
    try {
      // Get email from auth.users via RPC or fallback
      String? email;
      try {
        email = await _client
            .rpc('get_user_email', params: {'p_user_id': userId});
      } catch (rpcError) {
        // Fallback: get email from auth.users directly
        final userData = await _client
            .from('users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();
        email = userData?['email'];
      }

      if (email == null || email.isEmpty) {
        throw Exception('Staff email not found');
      }

      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://driveglow.app/auth/update-password',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Password reset email sent to $email')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _clearCreateForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _employeeIdController.clear();
    _selectedRole = 'WASHER';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _buildContent(),
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

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 10),
              Text(
                'Failed to load staff list',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final activeCount = _staffRows
        .where(
          (e) =>
              (e['membership_tier']?.toString().toUpperCase() == 'STAFF') &&
              ((e['is_active'] as bool?) ?? false),
        )
        .length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Manage Staff',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin can create, update role, activate/deactivate, and revoke staff access.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Total: ${_staffRows.length}')),
              Chip(label: Text('Active Staff: $activeCount')),
            ],
          ),
          const SizedBox(height: 14),
          if (!_isAdmin)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Admin access required to manage staff credentials.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ),
            )
          else ...[
            _buildCreateCard(),
            const SizedBox(height: 10),
          ],
          if (_staffRows.isEmpty)
            Text(
              'No staff accounts found.',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ..._staffRows.map(_buildProfileCard),
        ],
      ),
        ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Staff Credential',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Staff email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'WASHER', child: Text('Washer')),
                DropdownMenuItem(
                  value: 'SUPERVISOR',
                  child: Text('Supervisor'),
                ),
                DropdownMenuItem(
                  value: 'ADMIN',
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createStaffCredential,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(_creating ? 'Creating...' : 'Create Staff Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final name = (item['full_name'] ?? 'Unknown User').toString();
    final phone = (item['phone'] ?? '').toString();
    final tier = ((item['membership_tier'] ?? 'FREE').toString()).toUpperCase();
    final role = ((item['role_key'] ?? 'WASHER').toString()).toUpperCase();
    final employeeId = (item['employee_id'] ?? '').toString();
    final isActive = (item['is_active'] as bool?) ?? (tier == 'ADMIN');
    final isStaff = tier == 'STAFF';
    final isAdmin = tier == 'ADMIN';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${id.length > 8 ? id.substring(0, 8) : id}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
            if (employeeId.isNotEmpty)
              Text(
                'Employee ID: $employeeId',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
              ),
            Text(
              'Role: $role',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
            if (phone.isNotEmpty)
              Text(
                'Phone: $phone',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isStaff || isAdmin)
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                        : const Color(0xFF64748B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tier,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ),
                const Spacer(),
                if (_isAdmin && isStaff) ...[
                  OutlinedButton(
                    onPressed: _updating
                        ? null
                        : () => _showEditStaffDialog(
                            userId: id,
                            currentName: name,
                            currentPhone: phone,
                            currentRole: role,
                            currentActive: isActive,
                            currentEmployeeId: employeeId,
                          ),
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _updating ? null : () => _resetStaffPassword(id, name),
                    child: const Text('Reset Password'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _updating ? null : () => _removeStaff(id),
                    child: const Text('Remove'),
                  ),
                ] else if (isAdmin)
                  const Text(
                    'Admin',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditStaffDialog({
    required String userId,
    required String currentName,
    required String currentPhone,
    required String currentRole,
    required bool currentActive,
    String? currentEmployeeId,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    final employeeIdController = TextEditingController(text: currentEmployeeId ?? '');
    var role = currentRole;
    var isActive = currentActive;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Staff Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: employeeIdController,
                    decoration: const InputDecoration(labelText: 'Employee ID'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'WASHER', child: Text('Washer')),
                      DropdownMenuItem(
                        value: 'SUPERVISOR',
                        child: Text('Supervisor'),
                      ),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('Admin'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => role = value);
                    },
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateStaff(
                      userId: userId,
                      fullName: nameController.text.trim().isEmpty
                          ? currentName
                          : nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      role: role,
                      isActive: isActive,
                      membershipTier: 'STAFF',
                      employeeId: employeeIdController.text.trim().isEmpty
                          ? null
                          : employeeIdController.text.trim(),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }
}

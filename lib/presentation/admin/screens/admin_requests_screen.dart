import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shinex/theme/app_theme.dart';
import '../../../application/helpers/error_helper.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final _commentController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  String _filterStatus = 'all';
  String _activeTab = 'staff'; // staff or leave

  @override
  void initState() {
    super.initState();
    _loadAllRequests();
    _loadLeaveRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() => _loading = true);
    try {
      List<dynamic> response;
      
      // Query staff_requests without join (FK relationship may not exist)
      if (_filterStatus == 'all') {
        response = await Supabase.instance.client
            .from('staff_requests')
            .select()
            .order('created_at', ascending: false);
      } else {
        response = await Supabase.instance.client
            .from('staff_requests')
            .select()
            .eq('status', _filterStatus)
            .order('created_at', ascending: false);
      }

      // Get user data for each request
      final requestsWithUsers = <Map<String, dynamic>>[];
      for (final req in response) {
        final staffUserId = req['staff_user_id'] as String?;
        if (staffUserId != null) {
          try {
            final userResult = await Supabase.instance.client
                .rpc('lookup_staff_user', params: {'p_login_input': staffUserId});
            if (userResult != null && userResult.isNotEmpty) {
              final userData = Map<String, dynamic>.from(userResult.first);
              requestsWithUsers.add({
                ...req,
                'user_profiles': userData,
              });
            } else {
              requestsWithUsers.add(req);
            }
          } catch (e) {
            requestsWithUsers.add(req);
          }
        } else {
          requestsWithUsers.add(req);
        }
      }

      setState(() {
        _allRequests = List<Map<String, dynamic>>.from(requestsWithUsers);
      });
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Failed to Load Requests');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLeaveRequests() async {
    try {
      List<dynamic> response;
      
      if (_filterStatus == 'all') {
        response = await Supabase.instance.client
            .from('leave_requests')
            .select()
            .order('created_at', ascending: false);
      } else {
        response = await Supabase.instance.client
            .from('leave_requests')
            .select()
            .eq('status', _filterStatus)
            .order('created_at', ascending: false);
      }
      
      // Get staff names
      final leaveWithStaff = <Map<String, dynamic>>[];
      for (final req in response) {
        final staffUserId = req['staff_user_id'] as String?;
        if (staffUserId != null) {
          try {
            final userResult = await Supabase.instance.client
                .from('user_profiles')
                .select('full_name, employee_id')
                .eq('id', staffUserId)
                .maybeSingle();
            if (userResult != null) {
              leaveWithStaff.add({
                ...req,
                'staff_name': userResult['full_name'] ?? 'Unknown',
                'employee_id': userResult['employee_id'] ?? 'N/A',
              });
            } else {
              leaveWithStaff.add(req);
            }
          } catch (e) {
            leaveWithStaff.add(req);
          }
        } else {
          leaveWithStaff.add(req);
        }
      }
      
      setState(() {
        _leaveRequests = List<Map<String, dynamic>>.from(leaveWithStaff);
      });
    } catch (e) {
      debugPrint('Error loading leave requests: $e');
    }
  }

  Future<void> _approveLeaveRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Staff: ${request['staff_name'] ?? 'Unknown'}'),
            Text('Type: ${request['leave_type'] ?? 'N/A'}'),
            Text('Period: ${request['start_date']} to ${request['end_date']}'),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('leave_requests')
          .update({
            'status': 'approved',
            'admin_comment': _commentController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id']);
      
      _commentController.clear();
      _loadLeaveRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _denyLeaveRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Staff: ${request['staff_name'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for denial',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('leave_requests')
          .update({
            'status': 'denied',
            'admin_comment': _commentController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id']);
      
      _commentController.clear();
      _loadLeaveRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request denied')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request, {String? newPassword}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request by: ${request['user_profiles']?['full_name'] ?? 'Unknown'}'),
            Text('Type: ${_getTypeLabel(request['request_type'] ?? 'other')}'),
            const SizedBox(height: 16),
            if (request['request_type'] == 'password_reset') ...[
              const Text('Enter new password for staff:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Update request status
      await Supabase.instance.client
          .from('staff_requests')
          .update({
            'status': 'approved',
            'admin_comment': _commentController.text.trim(),
            'approved_by': user.id,
            'resolved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id']);

      // If password reset, update the password
      if (request['request_type'] == 'password_reset' && _newPasswordController.text.isNotEmpty) {
        final staffUserId = request['staff_user_id'] as String;
        // Get staff email from auth.users via RPC
        final email = await Supabase.instance.client
            .rpc('get_user_email', params: {'p_user_id': staffUserId});

        if (email != null && email.isNotEmpty) {
          // Note: Supabase doesn't allow direct password change by admin
          // Instead, we'll send a password reset email
          await Supabase.instance.client.auth.resetPasswordForEmail(
            email,
            redirectTo: 'https://driveglow.app/auth/update-password',
          );
        }
      }

      _commentController.clear();
      _newPasswordController.clear();
      _loadAllRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _denyRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request by: ${request['user_profiles']?['full_name'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for denial',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      await Supabase.instance.client
          .from('staff_requests')
          .update({
            'status': 'denied',
            'admin_comment': _commentController.text.trim(),
            'approved_by': user.id,
            'resolved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id']);

      _commentController.clear();
      _loadAllRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request denied')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _activeTab = 'staff');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTab == 'staff' ? PremiumTheme.orangePrimary : Colors.grey[200],
                      foregroundColor: _activeTab == 'staff' ? Colors.white : Colors.black,
                    ),
                    child: const Text('Staff Requests'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _activeTab = 'leave');
                      _loadLeaveRequests();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTab == 'leave' ? PremiumTheme.orangePrimary : Colors.grey[200],
                      foregroundColor: _activeTab == 'leave' ? Colors.white : Colors.black,
                    ),
                    child: const Text('Leave Requests'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _filterChip('Approved', 'approved'),
                const SizedBox(width: 8),
                _filterChip('Denied', 'denied'),
              ],
            ),
          ),
          Expanded(
            child: _activeTab == 'staff' 
              ? _buildStaffRequestsList()
              : _buildLeaveRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRequestsList() {
    return _loading && _allRequests.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _allRequests.isEmpty
            ? Center(child: Text('No staff requests found', style: TextStyle(color: Colors.grey[600])))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allRequests.length,
                itemBuilder: (context, index) {
                  return _buildRequestCard(_allRequests[index]);
                },
              );
  }

  Widget _buildLeaveRequestsList() {
    return _loading && _leaveRequests.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _leaveRequests.isEmpty
            ? Center(child: Text('No leave requests found', style: TextStyle(color: Colors.grey[600])))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _leaveRequests.length,
                itemBuilder: (context, index) {
                  return _buildLeaveRequestCard(_leaveRequests[index]);
                },
              );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final leaveType = (request['leave_type'] ?? 'other').toString();
    final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  child: Text(
                    (request['staff_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                    style: const TextStyle(color: PremiumTheme.orangePrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['staff_name'] ?? 'Unknown Staff',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ID: ${request['employee_id'] ?? 'NA'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_getLeaveTypeIcon(leaveType), size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(leaveType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Period: ${request['start_date']} to ${request['end_date']}'),
            if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(request['reason'], style: TextStyle(color: Colors.grey[700])),
            ],
            if (request['admin_comment'] != null && request['admin_comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 14, color: _getStatusColor(status)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request['admin_comment'],
                        style: TextStyle(fontSize: 12, color: _getStatusColor(status)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : () => _denyLeaveRequest(request),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Deny'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : () => _approveLeaveRequest(request),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLeaveTypeIcon(String type) {
    switch (type) {
      case 'sick': return Icons.local_hospital;
      case 'casual': return Icons.beach_access;
      case 'emergency': return Icons.emergency;
      default: return Icons.event;
    }
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
        _loadAllRequests();
      },
      selectedColor: PremiumTheme.orangePrimary.withValues(alpha: 0.2),
      checkmarkColor: PremiumTheme.orangePrimary,
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final requestType = (request['request_type'] ?? 'other').toString();
    final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '');
    final userProfile = request['user_profiles'] as Map<String, dynamic>?;
    final staffUser = request['staff_users'] as Map<String, dynamic>?;
    final adminComment = request['admin_comment'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  child: Text(
                    (userProfile?['full_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                    style: const TextStyle(color: PremiumTheme.orangePrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProfile?['full_name'] ?? 'Unknown Staff',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ID: ${staffUser?['employee_id'] ?? 'NA'} • ${userProfile?['email'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_getTypeIcon(requestType), size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_getTypeLabel(requestType), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(request['description'] ?? ''),
            if (adminComment != null && adminComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 14, color: _getStatusColor(status)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        adminComment,
                        style: TextStyle(fontSize: 12, color: _getStatusColor(status)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : () => _denyRequest(request),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Deny'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : () => _approveRequest(request),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'password_reset': return 'Password Reset';
      case 'leave': return 'Leave Request';
      case 'salary': return 'Salary Related';
      case 'profile_update': return 'Profile Update';
      default: return 'Other';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'password_reset': return Icons.lock_reset;
      case 'leave': return Icons.calendar_today;
      case 'salary': return Icons.attach_money;
      case 'profile_update': return Icons.person;
      default: return Icons.more_horiz;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'denied': return Colors.red;
      default: return Colors.orange;
    }
  }
}

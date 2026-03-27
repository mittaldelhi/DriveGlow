import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shinex/theme/app_theme.dart';

import '../../application/helpers/error_helper.dart';

class StaffRequestsScreen extends StatefulWidget {
  const StaffRequestsScreen({super.key});

  @override
  State<StaffRequestsScreen> createState() => _StaffRequestsScreenState();
}

class _StaffRequestsScreenState extends State<StaffRequestsScreen> {
  final _descriptionController = TextEditingController();
  String _selectedType = 'other';
  bool _loading = false;
  List<Map<String, dynamic>> _myRequests = [];

  @override
  void initState() {
    super.initState();
    _loadMyRequests();
  }

  Future<void> _loadMyRequests() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check user_profiles instead of staff_users
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return;
      final staffId = profile['id'] as String;

      final response = await Supabase.instance.client
          .from('staff_requests')
          .select()
          .eq('staff_user_id', staffId)
          .order('created_at', ascending: false);

      setState(() => _myRequests = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Use user_profiles instead of staff_users
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception('Staff not found');

      await Supabase.instance.client
          .from('staff_requests')
          .insert({
            'staff_user_id': profile['id'],
            'request_type': _selectedType,
            'description': _descriptionController.text.trim(),
            'status': 'pending',
          });

      _descriptionController.clear();
      _loadMyRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submit New Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(labelText: 'Request Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'password_reset', child: Text('Password Reset')),
                    DropdownMenuItem(value: 'leave', child: Text('Leave Request')),
                    DropdownMenuItem(value: 'salary', child: Text('Salary Related')),
                    DropdownMenuItem(value: 'profile_update', child: Text('Profile Update')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value ?? 'other'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Description', hintText: 'Describe your request...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Submit Request', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('My Requests', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (_loading && _myRequests.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_myRequests.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('No requests yet', style: TextStyle(color: Colors.grey[600]))))
        else
          ..._myRequests.map((request) => _buildRequestCard(request)),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final requestType = (request['request_type'] ?? 'other').toString();
    final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '');
    final adminComment = request['admin_comment'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(_getTypeLabel(requestType), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                if (createdAt != null) Text(DateFormat('dd MMM').format(createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(request['description'] ?? '', style: const TextStyle(fontSize: 14)),
            if (adminComment != null && adminComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(adminComment, style: const TextStyle(fontSize: 12, color: Colors.blue))),
                  ],
                ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'denied': return Colors.red;
      default: return Colors.orange;
    }
  }
}

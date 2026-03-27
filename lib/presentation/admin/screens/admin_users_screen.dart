import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userVehicles = [];
  List<Map<String, dynamic>> _userBookings = [];
  List<Map<String, dynamic>> _userFeedback = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults = [];
      _selectedUser = null;
    });

    try {
      final client = Supabase.instance.client;
      
      // Search by name, email, or phone
      var response = await client
          .from('user_profiles')
          .select('id, full_name, phone, avatar_url, created_at, membership_tier')
          .or('full_name.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);

      // Combine results
      final Map<String, Map<String, dynamic>> allResults = {};
      for (final row in response) {
        allResults[row['id'] as String] = Map<String, dynamic>.from(row);
      }

      setState(() {
        _searchResults = allResults.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDetails(String userId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final client = Supabase.instance.client;

      // Load user profile
      final profileResponse = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // Load user vehicles
      final vehiclesResponse = await client
          .from('user_vehicles')
          .select()
          .eq('user_id', userId);

      // Load user bookings
      final bookingsResponse = await client
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      // Load user feedback
      final feedbackResponse = await client
          .from('service_feedback')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        _selectedUser = profileResponse;
        _userVehicles = List<Map<String, dynamic>>.from(vehiclesResponse ?? []);
        _userBookings = List<Map<String, dynamic>>.from(bookingsResponse ?? []);
        _userFeedback = List<Map<String, dynamic>>.from(feedbackResponse ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Users',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _selectedUser == null ? _buildSearchView() : _buildUserDetailView(),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or phone...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _searchUsers(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _searchUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.orangePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Search', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: PremiumTheme.orangePrimary))
              : _error != null
                  ? Center(child: Text('Error: $_error', style: GoogleFonts.inter(color: Colors.red)))
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Search for users',
                                style: GoogleFonts.inter(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return _buildUserCard(user);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: () => _loadUserDetails(user['id']),
        leading: CircleAvatar(
          backgroundColor: PremiumTheme.orangePrimary,
          backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
          child: user['avatar_url'] == null
              ? Text(
                  (user['full_name'] ?? 'U')[0].toString().toUpperCase(),
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          user['full_name'] ?? 'Unknown',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          user['phone'] ?? 'No phone',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            user['membership_tier'] ?? 'FREE',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: PremiumTheme.orangePrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDetailView() {
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedUser = null),
              ),
              const SizedBox(width: 8),
              Text('User Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: PremiumTheme.orangePrimary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      _buildSectionCard(
                        'Profile',
                        [
                          _buildInfoRow('Name', _selectedUser?['full_name'] ?? 'N/A'),
                          _buildInfoRow('Phone', _selectedUser?['phone'] ?? 'N/A'),
                          _buildInfoRow('Tier', _selectedUser?['membership_tier'] ?? 'FREE'),
                          _buildInfoRow('Member Since', _selectedUser?['created_at'] != null
                              ? DateTime.parse(_selectedUser!['created_at']).toString().split(' ')[0]
                              : 'N/A'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Vehicles Section
                      _buildSectionCard(
                        'Vehicles (${_userVehicles.length})',
                        _userVehicles.isEmpty
                            ? [Center(child: Text('No vehicles', style: GoogleFonts.inter(color: Colors.grey)))]
                            : _userVehicles.map((v) => _buildInfoRow(
                                v['model'] ?? 'Unknown',
                                v['license_plate'] ?? '',
                              )).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Service History Section
                      _buildSectionCard(
                        'Service History (${_userBookings.length})',
                        _userBookings.isEmpty
                            ? [Center(child: Text('No bookings', style: GoogleFonts.inter(color: Colors.grey)))]
                            : _userBookings.take(10).map((b) => _buildBookingRow(b)).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Feedback Section
                      _buildSectionCard(
                        'Feedback (${_userFeedback.length})',
                        _userFeedback.isEmpty
                            ? [Center(child: Text('No feedback', style: GoogleFonts.inter(color: Colors.grey)))]
                            : _userFeedback.take(5).map((f) => _buildFeedbackRow(f)).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBookingRow(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['service_id']?.toString().split('::').last ?? 'Service',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${booking['vehicle_name'] ?? ''} • ${booking['vehicle_number'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking['created_at'] != null
                    ? DateTime.parse(booking['created_at']).toString().split(' ')[0]
                    : '',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackRow(Map<String, dynamic> feedback) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < ((feedback['rating'] as num?)?.toInt() ?? 0) ? Icons.star : Icons.star_border,
                size: 14,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feedback['comment'] ?? '',
              style: GoogleFonts.inter(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'inProgress':
        return Colors.blue;
      case 'lapsed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

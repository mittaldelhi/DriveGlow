import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';

import '../../application/helpers/error_helper.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/staff_providers.dart';
import '../../domain/models/booking_model.dart';
import '../../infrastructure/repositories/staff_ops_repository.dart';
import 'staff_requests_screen.dart';
import 'widgets/staff_widgets.dart';

class StaffPanelScreen extends ConsumerStatefulWidget {
  const StaffPanelScreen({super.key});

  @override
  ConsumerState<StaffPanelScreen> createState() => _StaffPanelScreenState();
}

class _StaffPanelScreenState extends ConsumerState<StaffPanelScreen> {
  int _tabIndex = 0;
  bool _busy = false;
  String _historyFilter = 'today';
  int _historyOffset = 0;
  List<Map<String, dynamic>> _historyData = [];
  bool _historyLoading = false;
  bool _hasMoreHistory = true;

  Future<void> _logoutStaff() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout from staff panel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/staff-login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffRepo = ref.read(staffOpsRepositoryProvider);
    return PopScope(
      canPop: false,
      child: FutureBuilder<StaffContext?>(
        future: staffRepo.getStaffContext(),
        builder: (context, snapshot) {
          // Show loading while fetching
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: PremiumTheme.orangePrimary),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              ),
            );
          }
          
          final staff = snapshot.data;
          final hasAccess = staff != null && staff.isActive;

          // If no staff data, show access denied
          if (!hasAccess) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      const Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Your staff account is not active.'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _logoutStaff,
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(_titleForTab(_tabIndex)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => Navigator.pushNamed(context, '/staff-qr-scanner'),
                  tooltip: 'Scan QR Code',
                ),
                IconButton(icon: const Icon(Icons.logout), onPressed: _logoutStaff, tooltip: 'Logout'),
              ],
            ),
            body: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildHomeTab(staff),
                      _buildHistoryTab(),
                      _buildAttendanceTab(),
                      const StaffRequestsScreen(),
                      _buildProfileTab(staff),
                    ],
                  ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _tabIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: PremiumTheme.orangePrimary,
              unselectedItemColor: Colors.grey[400],
              selectedFontSize: 12,
              unselectedFontSize: 12,
              onTap: (index) {
                setState(() => _tabIndex = index);
                if (index == 1 && _historyData.isEmpty) {
                  _loadHistory(reset: true);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.access_time_rounded), label: 'Attendance'),
                BottomNavigationBarItem(icon: Icon(Icons.request_page_rounded), label: 'Requests'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          );
        },
      ),
    );
  }

  String _titleForTab(int index) {
    switch (index) {
      case 0: return 'Staff Dashboard';
      case 1: return 'History';
      case 2: return 'Attendance';
      case 3: return 'Requests';
      case 4: return 'Profile';
      default: return 'Staff Panel';
    }
  }

  Widget _buildHomeTab(StaffContext? staff) {
    final staffRepo = ref.read(staffOpsRepositoryProvider);
    return FutureBuilder<StaffDashboardStats>(
      future: staffRepo.getTodayStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(streamTodayStatsProvider);
          },
          color: PremiumTheme.orangePrimary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Staff Info Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: PremiumTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.orangePrimary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      staff?.fullName.isNotEmpty == true ? staff!.fullName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff?.fullName ?? 'Staff',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${staff?.roleKey ?? 'STAFF'} • ID: ${staff?.employeeId ?? 'NA'}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        onPressed: () => Navigator.pushNamed(context, '/staff-qr-scanner'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Dashboard Cards - 2x3 Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                DashboardCard(
                  label: 'Total Services Today',
                  value: '${stats?.totalJobsToday ?? 0}',
                  icon: Icons.work,
                  color: PremiumTheme.orangePrimary,
                ),
                DashboardCard(
                  label: 'In Progress',
                  value: '${stats?.inProgressJobsToday ?? 0}',
                  icon: Icons.play_circle,
                  color: Colors.blue,
                ),
                DashboardCard(
                  label: 'Completed Today',
                  value: '${stats?.completedJobsToday ?? 0}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                DashboardCard(
                  label: 'Waiting',
                  value: '${stats?.pendingJobsToday ?? 0}',
                  icon: Icons.pending,
                  color: Colors.orange,
                ),
                const SizedBox(),
                const SizedBox(),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: PremiumTheme.orangePrimary),
                        const SizedBox(width: 8),
                        Text('Quick Actions', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/staff-qr-scanner'),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Scan QR'),
                          style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    final staffRepo = ref.read(staffOpsRepositoryProvider);
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: PremiumTheme.orangePrimary,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: staffRepo.getQueue(todayOnly: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: PremiumTheme.orangePrimary));
          }
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
            ]));
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return ListView(children: [
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No queue items for today', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 8),
                Text('All bookings may be completed or no new bookings', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ]))
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final booking = BookingModel.fromJson(item);
              return _buildQueueCard(booking);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final staffRepo = ref.read(staffOpsRepositoryProvider);
    return Column(
      children: [
        // Filter buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildFilterChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildFilterChip('Yesterday', 'yesterday'),
              const SizedBox(width: 8),
              _buildFilterChip('This Week', 'week'),
            ],
          ),
        ),
        // History list
        Expanded(
          child: _historyLoading
              ? const Center(child: CircularProgressIndicator(color: PremiumTheme.orangePrimary))
              : _historyData.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No bookings found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: () async => _loadHistory(reset: true),
                      color: PremiumTheme.orangePrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _historyData.length + (_hasMoreHistory ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _historyData.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: ElevatedButton(
                                  onPressed: _loadMoreHistory,
                                  child: const Text('View More'),
                                ),
                              ),
                            );
                          }
                          final item = _historyData[index];
                          final booking = BookingModel.fromJson(item);
                          return _buildQueueCard(booking);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _historyFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _historyFilter = value;
          _historyOffset = 0;
          _historyData = [];
          _hasMoreHistory = true;
        });
        _loadHistory(reset: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PremiumTheme.orangePrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _loadHistory({bool reset = false}) async {
    if (reset) {
      setState(() {
        _historyOffset = 0;
        _historyData = [];
        _hasMoreHistory = true;
      });
    }
    
    setState(() => _historyLoading = true);
    
    try {
      final staffRepo = ref.read(staffOpsRepositoryProvider);
      final data = await staffRepo.getHistory(
        filter: _historyFilter,
        limit: 5,
        offset: _historyOffset,
      );
      
      setState(() {
        if (reset) {
          _historyData = data;
        } else {
          _historyData.addAll(data);
        }
        _hasMoreHistory = data.length >= 5;
        _historyLoading = false;
      });
    } catch (e) {
      setState(() => _historyLoading = false);
    }
  }

  void _loadMoreHistory() {
    setState(() {
      _historyOffset += 5;
    });
    _loadHistory();
  }

  Widget _buildQueueCard(BookingModel booking) {
    Color statusColor;
    String statusLabel;
    
    switch (booking.status) {
      case BookingStatus.pending:
      case BookingStatus.confirmed:
        statusColor = Colors.orange;
        statusLabel = 'Waiting';
        break;
      case BookingStatus.inProgress:
        statusColor = Colors.blue;
        statusLabel = 'In Progress';
        break;
      case BookingStatus.completed:
        statusColor = Colors.green;
        statusLabel = 'Completed';
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      case BookingStatus.lapsed:
        statusColor = Colors.red[700]!;
        statusLabel = 'Lapsed';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
              children: [
                Text(
                  '#${booking.id.substring(0, 4).toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                StatusChip(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>?>(
              future: _getCustomerInfo(booking.userId),
              builder: (context, snapshot) {
                final customerName = snapshot.data?['full_name'] ?? 'Customer';
                return Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: PremiumTheme.orangePrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: PremiumTheme.orangePrimary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              booking.vehicleName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'License Plate: ${booking.vehicleNumber}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _serviceName(booking.serviceId),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: PremiumTheme.orangePrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: booking.isSubscriptionBooking 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.isSubscriptionBooking ? 'Subscription' : 'One-time',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: booking.isSubscriptionBooking ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed)
                  Expanded(
                    child: GradientButton(
                      text: 'Start Job',
                      icon: Icons.play_arrow,
                      onPressed: _busy ? null : () => _startService(booking),
                    ),
                  ),
                if (booking.status == BookingStatus.inProgress)
                  Expanded(
                    child: GradientButton(
                      text: 'Complete',
                      icon: Icons.check,
                      onPressed: _busy ? null : () => _completeService(booking),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    text: 'Details',
                    isSecondary: true,
                    onPressed: () => _showBookingDetailsDialog(booking),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attendance Calendar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              // Navigate to previous month
                            });
                          },
                        ),
                        Text('${_monthName(now.month)} ${now.year}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              // Navigate to next month
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _legendItem('P = Present', Colors.green),
                    _legendItem('WO = Weekoff', Colors.blue),
                    _legendItem('L = Leave', Colors.orange),
                    _legendItem('H = Holiday', Colors.red),
                    _legendItem('Blank = Not Marked', Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                // Simple calendar grid
                _buildCalendarGrid(now),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Mark today attendance
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mark Today\'s Status', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusButton('Present', Colors.green, () => _markAttendance('present')),
                    _statusButton('Weekoff', Colors.blue, () => _markAttendance('weekoff')),
                    _statusButton('Leave', Colors.orange, () => _showLeaveRequestDialog()),
                    _statusButton('Holiday', Colors.red, () => _markAttendance('holiday')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Leave Requests Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Leave Requests', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                    TextButton.icon(
                      onPressed: () => _showLeaveRequestDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Apply Leave'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leave requests require admin approval',
                          style: TextStyle(color: Colors.orange[700], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getLeaveRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return Text('No leave requests', style: TextStyle(color: Colors.grey[500]));
                    }
                    return Column(
                      children: requests.map((req) => _buildLeaveRequestItem(req)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveRequestItem(Map<String, dynamic> req) {
    final status = req['status'] as String;
    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'denied':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req['leave_type'].toString().toUpperCase()} Leave',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${req['start_date']} to ${req['end_date']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getLeaveRequests() async {
    try {
      final staff = await ref.read(staffOpsRepositoryProvider).getStaffContext();
      if (staff == null) return [];
      
      final response = await Supabase.instance.client
          .from('leave_requests')
          .select()
          .eq('staff_user_id', staff.userId)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  void _showBookingDetailsDialog(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Booking Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _getCustomerInfo(booking.userId),
                  builder: (context, snapshot) {
                    final customerName = snapshot.data?['full_name'] ?? 'Customer';
                    final customerPhone = snapshot.data?['phone'] ?? 'N/A';
                    return Column(
                      children: [
                        _detailRow(Icons.person, 'Customer Name', customerName),
                        _detailRow(Icons.phone, 'Mobile', customerPhone),
                      ],
                    );
                  },
                ),
                _detailRow(Icons.tag, 'Booking ID', '#${booking.id.substring(0, 8).toUpperCase()}'),
                _detailRow(Icons.calendar_today, 'Date', DateFormat('dd MMM yyyy, hh:mm a').format(booking.appointmentDate)),
                _detailRow(Icons.directions_car, 'Vehicle', '${booking.vehicleName} (${booking.vehicleNumber})'),
                _detailRow(Icons.build, 'Service', _serviceName(booking.serviceId)),
                _detailRow(Icons.currency_rupee, 'Price', '₹${booking.totalPrice.toStringAsFixed(0)}'),
                _detailRow(Icons.info_outline, 'Status', booking.status.name.toUpperCase()),
                if (booking.completedAt != null)
                  _detailRow(Icons.check_circle, 'Completed At', DateFormat('dd MMM yyyy, hh:mm a').format(booking.completedAt!)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _startService(booking);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Job'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumTheme.orangePrimary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (booking.status == BookingStatus.inProgress)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _completeService(booking);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: PremiumTheme.orangePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveRequestDialog() {
    String selectedType = 'sick';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Apply for Leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['sick', 'casual', 'emergency', 'other'].map((type) => 
                    ChoiceChip(
                      label: Text(type.toUpperCase()),
                      selected: selectedType == type,
                      onSelected: (selected) {
                        setDialogState(() => selectedType = type);
                      },
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Select Date Range'),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: Leave requires admin approval',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
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
              onPressed: () async {
                Navigator.pop(context);
                await _submitLeaveRequest(selectedType, startDate, endDate, reasonController.text);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitLeaveRequest(String type, DateTime start, DateTime end, String reason) async {
    try {
      final staff = await ref.read(staffOpsRepositoryProvider).getStaffContext();
      if (staff == null) return;
      
      await Supabase.instance.client.from('leave_requests').insert({
        'staff_user_id': staff.userId,
        'leave_type': type,
        'start_date': DateFormat('yyyy-MM-dd').format(start),
        'end_date': DateFormat('yyyy-MM-dd').format(end),
        'reason': reason,
        'status': 'pending',
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted! Admin will review it.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
      }
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCalendarGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    
    return Column(
      children: [
        // Day headers
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])))))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: startWeekday + lastDay.day,
          itemBuilder: (context, index) {
            if (index < startWeekday) {
              return const SizedBox();
            }
            final day = index - startWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
            final isFuture = date.isAfter(DateTime.now());
            
            // Sample markers for demo (P=Present, WO=Weekoff, L=Leave, H=Holiday)
            String marker = '';
            Color? markerColor;
            
            if (isFuture) {
              marker = '';
              markerColor = Colors.grey[300];
            } else if (day % 7 == 0) {
              marker = 'WO'; // Sunday - weekoff
              markerColor = Colors.blue;
            } else if (day % 5 == 0) {
              marker = 'H'; // Friday - holiday demo
              markerColor = Colors.red;
            } else if (day % 3 == 0) {
              marker = 'L'; // Leave demo
              markerColor = Colors.orange;
            } else {
              marker = 'P'; // Present
              markerColor = Colors.green;
            }
            
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: markerColor?.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(color: PremiumTheme.orangePrimary, width: 2) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isFuture ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  if (!isFuture)
                    Text(
                      marker,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: markerColor,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _statusButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _busy ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Future<void> _markAttendance(String status) async {
    setState(() => _busy = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      await Supabase.instance.client.from('staff_attendance_calendar').insert({
        'staff_user_id': user.id,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'status': status,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked as $status')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _monthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  Widget _attendanceRow(String label, String value, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey[600])), Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor))]));
  }

  Widget _buildProfileTab(StaffContext? staff) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  child: Text(staff?.fullName.isNotEmpty == true ? staff!.fullName[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: PremiumTheme.orangePrimary)),
                ),
                const SizedBox(height: 12),
                Text(staff?.fullName ?? 'Staff', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${staff?.roleKey ?? 'STAFF'} • ${staff?.employeeId ?? 'NA'}', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(staff?.isActive == true ? 'Active' : 'Inactive', style: TextStyle(color: staff?.isActive == true ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Staff Stats
        FutureBuilder<int>(
          future: ref.read(staffOpsRepositoryProvider).getLifetimeCompletedJobs(),
          builder: (context, snapshot) {
            final lifetimeJobs = snapshot.data ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('$lifetimeJobs', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: PremiumTheme.orangePrimary)),
                          Text('Lifetime Jobs', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    Expanded(
                      child: FutureBuilder<StaffAttendanceState>(
                        future: ref.read(staffOpsRepositoryProvider).getTodayAttendance(),
                        builder: (context, attState) {
                          final duration = _workedDuration(attState.data ?? StaffAttendanceState(logId: null, checkInAt: null, checkOutAt: null, checkedIn: false), DateTime.now());
                          return Column(
                            children: [
                              Text(duration, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: PremiumTheme.orangePrimary)),
                              Text('Today Hours', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Menu Options
        _buildProfileMenuItem(Icons.person_outline, 'Edit Profile', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit profile coming soon')));
        }),
        _buildProfileMenuItem(Icons.notifications_outlined, 'Notifications', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications coming soon')));
        }),
        _buildProfileMenuItem(Icons.lock_outline, 'Change Password', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Change password coming soon')));
        }),
        _buildProfileMenuItem(Icons.help_outline, 'Help & Support', () {
          Navigator.pushNamed(context, '/chat');
        }),
        _buildProfileMenuItem(Icons.info_outline, 'About', () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('DriveGlow Staff'),
              content: const Text('Version 1.0.4\nStaff Panel for DriveGlow Car Wash'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logoutStaff,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: PremiumTheme.orangePrimary),
        title: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  String _serviceName(String ref) {
    if (ref.isEmpty) return 'Unknown Service';
    
    // Handle UUID format service IDs
    if (ref.contains('::')) {
      final parts = ref.split('::');
      if (parts.length >= 3) {
        final serviceName = parts.sublist(2).join(' ');
        // Clean up the service name
        return _cleanServiceName(serviceName);
      }
    }
    return _cleanServiceName(ref);
  }

  String _cleanServiceName(String name) {
    // Remove UUID-like strings and clean up
    final cleaned = name
        .replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'), '')
        .replaceAll(RegExp(r'::+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'Standard Service';
  }

  Future<Map<String, dynamic>?> _getCustomerInfo(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, phone')
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  String _fmtTime(DateTime? time) {
    if (time == null) return '--';
    return DateFormat('hh:mm a').format(time);
  }

  String _workedDuration(StaffAttendanceState state, DateTime now) {
    if (state.checkInAt == null) return '0h 0m';
    final end = state.checkOutAt ?? now;
    final d = end.difference(state.checkInAt!);
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed: return Colors.green;
      case BookingStatus.inProgress: return Colors.orange;
      case BookingStatus.cancelled: return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _startService(BookingModel booking) async {
    setState(() => _busy = true);
    try {
      try {
        await ref.read(staffOpsRepositoryProvider).startService(booking.id);
      } catch (_) {
        await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: booking.id, status: BookingStatus.inProgress);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Service started for ${booking.vehicleName}')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeService(BookingModel booking) async {
    // First, complete the service
    setState(() => _busy = true);
    try {
      try {
        await ref.read(staffOpsRepositoryProvider).completeService(booking.id);
      } catch (_) {
        await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: booking.id, status: BookingStatus.completed);
      }
      if (!mounted) return;
      
      // Send notification to customer
      try {
        await _sendCompletionNotification(booking);
      } catch (e) {
        // Notification failure shouldn't block completion
        debugPrint('Notification error: $e');
      }
      
      // Show rating dialog
      await _showRatingDialog(booking);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service completed!')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCompletionNotification(BookingModel booking) async {
    try {
      final customerInfo = await _getCustomerInfo(booking.userId);
      if (customerInfo == null) return;
      
      final serviceName = _serviceName(booking.serviceId);
      
      // Insert notification into user_notifications table
      await Supabase.instance.client.from('user_notifications').insert({
        'user_id': booking.userId,
        'title': 'Service Completed!',
        'message': 'Your car wash service ($serviceName) for vehicle ${booking.vehicleNumber} has been completed. Thank you for choosing DriveGlow!',
        'type': 'booking',
        'booking_id': booking.id,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _showRatingDialog(BookingModel booking) async {
    int selectedRating = 5;
    final commentController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was the customer\'s vehicle?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Submit rating
                try {
                  await ref.read(staffOpsRepositoryProvider).submitCustomerRating(
                    bookingId: booking.id,
                    rating: selectedRating.toDouble(),
                    comment: commentController.text.trim(),
                  );
                } catch (e) {
                  // Rating is optional, continue even if fails
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkInOut({required bool checkIn}) async {
    setState(() => _busy = true);
    try {
      if (checkIn) {
        await ref.read(staffOpsRepositoryProvider).checkIn();
      } else {
        await ref.read(staffOpsRepositoryProvider).checkOut();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(checkIn ? 'Checked in.' : 'Checked out.')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

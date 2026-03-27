import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/feedback_analytics_screen.dart';
import '../screens/admin_standard_services_screen.dart';
import '../screens/admin_subscription_management.dart';
import '../screens/admin_staff_management_screen.dart';
import '../screens/admin_requests_screen.dart';
import '../screens/booking_management_screen.dart';
import '../screens/admin_coupon_management_screen.dart';
import '../screens/admin_tickets_screen.dart';
import '../screens/admin_users_screen.dart';
import '../../../theme/app_theme.dart';

class AdminNavNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final adminNavIndexProvider = NotifierProvider<AdminNavNotifier, int>(() => AdminNavNotifier());

class AdminScaffold extends ConsumerStatefulWidget {
  final Widget? child;
  final int initialIndex;

  const AdminScaffold({super.key, this.child, this.initialIndex = 0});

  @override
  ConsumerState<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends ConsumerState<AdminScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNavIndexProvider.notifier).setIndex(widget.initialIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(adminNavIndexProvider);

    final List<Widget> screens = [
      const _HomeTab(),
      const AdminDashboardScreen(),
      const _SettingsTab(),
      const _ProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showLogoutConfirmation(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DriveGlow Admin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              Text(
                'MANAGE YOUR BUSINESS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: Color(0xFF1A1A1A),
              ),
              onPressed: () {},
            ),
            PopupMenuButton<String>(
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: PremiumTheme.orangePrimary,
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF1A1A1A)),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    }
                  }
                }
              },
            ),
          ],
        ),
        body: IndexedStack(index: selectedIndex, children: screens),
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
            currentIndex: selectedIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: PremiumTheme.orangePrimary,
            unselectedItemColor: Colors.grey[400],
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            onTap: (index) => ref.read(adminNavIndexProvider.notifier).setIndex(index),
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
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Admin Panel?'),
        content: const Text('Do you want to logout and exit to login?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStats(context),
          const SizedBox(height: 24),
          _buildMenuGrid(context, ref),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final stats = [
      _StatItem(label: 'Today\'s Revenue', value: '\$2,450', icon: Icons.attach_money_rounded, color: Colors.green),
      _StatItem(label: 'Bookings Today', value: '28', icon: Icons.calendar_today_rounded, color: Colors.blue),
      _StatItem(label: 'Active Staff', value: '8/10', icon: Icons.people_rounded, color: PremiumTheme.orangePrimary),
      _StatItem(label: 'Pending Requests', value: '5', icon: Icons.pending_actions_rounded, color: Colors.purple),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final stat = stats[index];
              return Container(
                width: 130,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: stat.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(stat.icon, size: 16, color: stat.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stat.value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      stat.label,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(BuildContext context, WidgetRef ref) {
    final menuItems = [
      _MenuItem(label: 'Users', icon: Icons.people_rounded, color: Colors.teal, screen: const AdminUsersScreen()),
      _MenuItem(label: 'Analytics', icon: Icons.analytics_rounded, color: Colors.blue, screen: const FeedbackAnalyticsScreen()),
      _MenuItem(label: 'Subscriptions', icon: Icons.card_membership_rounded, color: PremiumTheme.orangePrimary, screen: const AdminSubscriptionManagementScreen()),
      _MenuItem(label: 'Services', icon: Icons.build_rounded, color: Colors.teal, screen: const AdminStandardServicesScreen()),
      _MenuItem(label: 'Staff', icon: Icons.groups_rounded, color: Colors.indigo, screen: const AdminStaffManagementScreen()),
      _MenuItem(label: 'Requests', icon: Icons.request_page_rounded, color: Colors.purple, screen: const AdminRequestsScreen()),
      _MenuItem(label: 'Bookings', icon: Icons.book_online_rounded, color: Colors.orange, screen: const BookingManagementScreen()),
      _MenuItem(label: 'Coupons', icon: Icons.local_offer_rounded, color: Colors.green, screen: const AdminCouponManagementScreen()),
      _MenuItem(label: 'Tickets', icon: Icons.support_agent_rounded, color: Colors.redAccent, screen: const AdminTicketsScreen()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Features',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _buildMenuCard(context, item, ref);
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuItem item, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => item.screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem({required this.label, required this.value, required this.icon, required this.color});
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;

  _MenuItem({required this.label, required this.icon, required this.color, required this.screen});
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsTile(Icons.notifications_outlined, 'Notifications', 'Manage push notifications', () {}),
        _buildSettingsTile(Icons.language_rounded, 'Language', 'English', () {}),
        _buildSettingsTile(Icons.security_rounded, 'Security', 'Password & 2FA', () {}),
        _buildSettingsTile(Icons.info_outline_rounded, 'About', 'App version 1.0.0', () {}),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: PremiumTheme.orangePrimary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: PremiumTheme.orangePrimary,
            child: const Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Admin',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'admin@driveglow.com',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          _buildProfileTile(Icons.person_outline, 'Edit Profile', () {}),
          _buildProfileTile(Icons.lock_outline, 'Change Password', () {}),
          _buildProfileTile(Icons.help_outline, 'Help & Support', () {}),
          _buildProfileTile(Icons.logout, 'Logout', () {}),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: PremiumTheme.orangePrimary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

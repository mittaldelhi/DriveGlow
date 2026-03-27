import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickActions(context),
          const SizedBox(height: 24),
          _buildStatsGrid(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                label: 'HR Home',
                icon: Icons.people_alt_rounded,
                color: Colors.indigo,
                onTap: () => Navigator.pushNamed(context, '/admin/hr-home'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final stats = [
      _DashboardStat(
        label: 'Today\'s Revenue',
        value: '\$2,450',
        trend: '+12%',
        isPositive: true,
        icon: Icons.attach_money_rounded,
        color: Colors.green,
      ),
      _DashboardStat(
        label: 'This Week',
        value: '\$18,320',
        trend: '+8%',
        isPositive: true,
        icon: Icons.calendar_view_week_rounded,
        color: Colors.blue,
      ),
      _DashboardStat(
        label: 'Total Customers',
        value: '1,247',
        trend: '+5%',
        isPositive: true,
        icon: Icons.people_rounded,
        color: Colors.indigo,
      ),
      _DashboardStat(
        label: 'Active Subscriptions',
        value: '342',
        trend: '+15%',
        isPositive: true,
        icon: Icons.card_membership_rounded,
        color: PremiumTheme.orangePrimary,
      ),
      _DashboardStat(
        label: 'Total Staff',
        value: '12',
        trend: '2 inactive',
        isPositive: false,
        icon: Icons.groups_rounded,
        color: Colors.teal,
      ),
      _DashboardStat(
        label: 'Pending Requests',
        value: '5',
        trend: 'Needs attention',
        isPositive: false,
        icon: Icons.pending_actions_rounded,
        color: Colors.purple,
      ),
      _DashboardStat(
        label: 'Today\'s Bookings',
        value: '28',
        trend: '+3',
        isPositive: true,
        icon: Icons.book_online_rounded,
        color: Colors.orange,
      ),
      _DashboardStat(
        label: 'Completed Today',
        value: '22',
        trend: '78% completion',
        isPositive: true,
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stat.icon, size: 20, color: stat.color),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stat.isPositive 
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stat.trend,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: stat.isPositive ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.value,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    stat.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardStat {
  final String label;
  final String value;
  final String trend;
  final bool isPositive;
  final IconData icon;
  final Color color;

  _DashboardStat({
    required this.label,
    required this.value,
    required this.trend,
    required this.isPositive,
    required this.icon,
    required this.color,
  });
}

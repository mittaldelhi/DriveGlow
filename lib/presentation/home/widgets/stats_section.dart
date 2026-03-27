import 'package:flutter/material.dart';
import 'package:shinex/theme/app_theme.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            icon: Icons.star_rounded,
            value: '4.8',
            label: '1.2k+ Reviews',
            showBorder: false,
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey.withValues(alpha: 0.2), // Divider
          ),
          _buildStatItem(
            icon: Icons.groups_rounded,
            value: '2.5k+',
            label: 'Cars Serviced',
            showBorder: false,
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey.withValues(alpha: 0.2), // Divider
          ),
          _buildStatItem(
            icon: Icons.verified_user_rounded,
            value: null, // Icon only for value area
            label: 'Certified Pros',
            showBorder: false,
            isCertified: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String? value,
    required String label,
    required bool showBorder,
    bool isCertified = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: PremiumTheme.orangePrimary, size: 24),
              if (value != null) ...[
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.darkBg,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

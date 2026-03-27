import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shinex/theme/app_theme.dart';

class GlassBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    this.selectedIndex = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            12 + MediaQuery.of(context).padding.bottom,
          ), // Bottom padding for iPhone home bar area
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.loyalty_rounded, 'Subscriptions'),
              _buildNavItem(2, Icons.calendar_month_rounded, 'My Booking'),
              _buildNavItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

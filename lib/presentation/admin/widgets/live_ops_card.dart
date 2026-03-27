import 'package:flutter/material.dart';

class LiveOpsCard extends StatelessWidget {
  final int carsWaiting;
  final String waitTime;
  final int activeStaff;
  final int totalStaff;

  const LiveOpsCard({
    super.key,
    required this.carsWaiting,
    required this.waitTime,
    required this.activeStaff,
    required this.totalStaff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Operations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SYSTEM OK',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLiveStatRow(
            context,
            icon: Icons.directions_car_rounded,
            iconColor: Colors.orange,
            label: 'Queue Status',
            subLabel: '$carsWaiting Cars Waiting',
            value: waitTime,
          ),
          const Divider(height: 32),
          _buildLiveStatRow(
            context,
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFFF0541E),
            label: 'Staff Availability',
            subLabel: '$activeStaff/$totalStaff Active',
            isStaff: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subLabel,
    String? value,
    bool isStaff = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        if (value != null)
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        if (isStaff)
          // Use a fixed width Stack to render overlapping staff circles
          SizedBox(
            width: 72,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  child: _plainStaffCircle(Colors.indigo[200]!),
                ),
                Positioned(
                  left: 20,
                  child: _plainStaffCircle(Colors.indigo[300]!),
                ),
                Positioned(
                  left: 40,
                  child: _plainStaffCircle(Colors.indigo[100]!),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _plainStaffCircle(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

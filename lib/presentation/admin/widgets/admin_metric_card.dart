import 'package:flutter/material.dart';

class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final bool isPositive;
  final List<double> history;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.trend,
    this.isPositive = true,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF0541E),
                ),
              ),
              if (trend.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: Colors.green,
                ),
                Text(
                  trend.split(' ').last,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: () {
                if (history.isEmpty) return <Widget>[];
                final maxVal = history.reduce((a, b) => a > b ? a : b);
                return history.map((val) {
                  final normalizedHeight = maxVal > 0
                      ? (val / maxVal) * 30.0
                      : 0.0;
                  return Container(
                    width: 8,
                    height: normalizedHeight.clamp(0.0, 30.0),
                    decoration: BoxDecoration(
                      color: val == maxVal
                          ? const Color(0xFFF0541E)
                          : const Color(0xFFF0541E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList();
              }(),
            ),
          ),
        ],
      ),
    );
  }
}

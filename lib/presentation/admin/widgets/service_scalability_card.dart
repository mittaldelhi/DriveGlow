import 'package:flutter/material.dart';

class ServiceScalabilityCard extends StatelessWidget {
  final Map<String, double> scalability;

  const ServiceScalabilityCard({super.key, required this.scalability});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Scalability',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          _buildScalabilityRow('CAR WASH UNIT', 0.82, const Color(0xFFF0541E)),
          const SizedBox(height: 20),
          _buildScalabilityRow('MECHANIC BAY', 0.94, const Color(0xFFF0541E)),
          const SizedBox(height: 20),
          _buildScalabilityRow(
            'RETAIL/ACCESSORIES',
            0.45,
            const Color(0xFFF0541E).withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildScalabilityRow(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[300],
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}% CAPACITY',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFECEFF1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

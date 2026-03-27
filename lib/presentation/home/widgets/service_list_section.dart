import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/auth_providers.dart';
import '../../../../theme/app_theme.dart';

class ServiceListSection extends ConsumerWidget {
  const ServiceListSection({super.key});

  static final List<Map<String, String>> _services = [
    {
      'name': 'Washing Care',
      'description': 'Professional car washing with premium tools and eco-friendly products',
      'image': 'assets/images/washingcare.jpg',
    },
    {
      'name': 'Maintenance Care',
      'description': 'Expert maintenance services to keep your vehicle in top condition',
      'image': 'assets/images/Maintenance.jpg',
    },
    {
      'name': 'Accessories Care',
      'description': 'Premium accessories to enhance your driving experience',
      'image': 'assets/images/Accessories.jpg',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our Services',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: PremiumTheme.darkBg,
            ),
          ),
          const SizedBox(height: 16),
          // Show 3 hardcoded service cards
          Column(
            children: _services.map((service) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildServiceCard(context, ref, service),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> service,
  ) {
    final name = service['name'] ?? '';
    final description = service['description'] ?? '';

    return Container(
      height: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: AssetImage(service['image'] ?? ''),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // No price chip - removed
                    const SizedBox(),
                    // Action Button
                    ElevatedButton(
                      onPressed: () {
                        final isGuest = ref.read(isGuestProvider);
                        if (isGuest) {
                          Navigator.pushNamed(context, '/login');
                        } else {
                          Navigator.pushNamed(context, '/subscription-choice');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumTheme.orangePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'View Packages',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

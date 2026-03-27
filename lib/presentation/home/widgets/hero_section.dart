import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shinex/theme/app_theme.dart';
import '../../../application/providers/profile_providers.dart';
import '../../../application/providers/auth_providers.dart';
import '../../widgets/main_scaffold.dart';

class HeroSection extends ConsumerWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final profileAsync = ref.watch(userProfileProvider);

    return SizedBox(
      height: 500,
      width: double.infinity,
      child: Stack(
        children: [
          // ─── Background Image ───
          Positioned.fill(
            child: Image.asset(
              'images/HERO.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PremiumTheme.darkBg,
                        Color(0xFF1A1A2E),
                        Color(0xFF16213E),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 80,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Dark Gradient Overlay ───
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ─── Content ───
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Push content down to account for header
                  const SizedBox(height: 72),

                  const SizedBox(height: 24),

                  // ─── Title ───
                  SizedBox(
                    width: screenWidth * 0.8,
                    child: Text(
                      'Premium Car Care.\nReimagined.',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 56 : 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Subtitle ───
                  SizedBox(
                    width: screenWidth > 600 ? 560 : double.infinity,
                    child: profileAsync.maybeWhen(
                      data: (profile) {
                        final primaryCar = profile?.vehicles.isNotEmpty == true
                            ? profile!.vehicles.firstWhere(
                                (v) => v.isPrimary,
                                orElse: () => profile.vehicles.first,
                              )
                            : null;

                        String subtitle =
                            'Eco-friendly detailing, ceramic protection & accessories — all in one platform.';
                        if (primaryCar != null) {
                          subtitle =
                              'Get your ${primaryCar.model} the luxury treatment it deserves today.';
                        }

                        return Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: screenWidth > 600 ? 18 : 15,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        );
                      },
                      orElse: () => Text(
                        'Eco-friendly detailing, ceramic protection & accessories — all in one platform.',
                        style: TextStyle(
                          fontSize: screenWidth > 600 ? 18 : 15,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Action Buttons ───
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Book Now — filled orange
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final isGuest = ref.read(isGuestProvider);
                            if (isGuest) {
                              Navigator.pushNamed(context, '/login');
                            } else {
                              Navigator.pushNamed(context, '/our-services/standard-care');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumTheme.orangePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PremiumTheme.radiusSM,
                              ),
                            ),
                            elevation: 4,
                            shadowColor: PremiumTheme.orangePrimary.withOpacity(
                              0.4,
                            ),
                          ),
                          child: const Text(
                            'Book Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      // Explore Services — outlined glass
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            // Switch to Services Tab (Index 1)
                            ref.read(navIndexProvider.notifier).state = 1;
                            // Ensure we are on the main scaffold
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.45),
                              width: 1.5,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                PremiumTheme.radiusSM,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Explore Services',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
  }
}

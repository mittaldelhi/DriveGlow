import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/providers/subscription_plan_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/models/subscription_plan_model.dart';
import '../../theme/app_theme.dart';

/// Featured Services Screen - Displays top 5 subscription plans
/// Admin can manage these from the admin panel
class FeaturedServicesScreen extends ConsumerWidget {
  const FeaturedServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(
      subscriptionPlansByDurationProvider('Monthly'),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F6),
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Our Services',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: plansAsync.when(
          loading: () => _buildSkeletonGrid(),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Oops! Something went wrong.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(
                    subscriptionPlansByDurationProvider('Monthly'),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (plans) {
            // Get top 5 plans (featured first, then by displayOrder)
            final sortedPlans = List<SubscriptionPlanModel>.from(plans);
            sortedPlans.sort((a, b) {
              // Featured first
              if (a.isFeatured != b.isFeatured) {
                return b.isFeatured ? 1 : -1;
              }
              // Then by displayOrder
              return a.displayOrder.compareTo(b.displayOrder);
            });

            final topPlans = sortedPlans.take(5).toList();

            if (topPlans.isEmpty) return _buildEmptyState();
            return _buildServicesGrid(ref, topPlans);
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.card_membership_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No services available',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(WidgetRef ref, List<SubscriptionPlanModel> plans) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plans.length} premium plans',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.orangePrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the perfect plan for your vehicle',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Services Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildServiceCard(context, ref, plans[index]),
              childCount: plans.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, WidgetRef ref, SubscriptionPlanModel plan) {
    return GestureDetector(
      onTap: () {
        final isGuest = ref.read(isGuestProvider);
        if (isGuest) {
          Navigator.pushNamed(context, '/login');
        } else {
          Navigator.pushNamed(
            context,
            '/payment',
            arguments: {
              'isService': false,
              'planId': plan.id,
              'planName': plan.name,
              'duration': plan.duration,
              'price': plan.price,
              'tier': plan.tier,
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tier badge
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                    PremiumTheme.orangePrimary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: PremiumTheme.orangePrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.tier.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: PremiumTheme.orangePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${plan.price.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/mo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Services per month
                    Text(
                      plan.showUnlimited 
                          ? 'Unlimited services/month' 
                          : '${plan.serviceUsageLimits?.values.fold(0, (sum, v) => sum + v) ?? 0} services/month',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () {
                          final isGuest = ref.read(isGuestProvider);
                          if (isGuest) {
                            Navigator.pushNamed(context, '/login');
                          } else {
                            Navigator.pushNamed(
                              context,
                              '/payment',
                              arguments: {
                                'isService': false,
                                'planId': plan.id,
                                'planName': plan.name,
                                'duration': plan.duration,
                                'price': plan.price,
                                'tier': plan.tier,
                                'isSubscription': true,
                              },
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.orangePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Subscribe',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../application/helpers/booking_validation_helper.dart';
import '../../application/providers/auth_providers.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/profile_providers.dart';
import '../../application/providers/subscription_plan_providers.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/models/subscription_plan_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        color: const Color(0xFFF8F6F6),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (profile) {
            if (user == null) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Login'),
                ),
              );
            }

            return FutureBuilder<List<BookingModel>>(
              future: ref
                  .read(bookingRepositoryProvider)
                  .getUserBookings(user.id),
              builder: (context, snapshot) {
                final bookings = snapshot.data ?? const <BookingModel>[];
                final plansAsync = ref.watch(allSubscriptionPlansProvider);
                Map<String, dynamic> plansById = {};
                plansAsync.whenData((plans) {
                  for (final plan in plans) {
                    plansById[plan.id] = {
                      'name': plan.name,
                      'duration': plan.duration,
                      'show_unlimited': plan.showUnlimited,
                    };
                  }
                });
                return _buildContent(
                  context,
                  ref,
                  user.fullName ?? 'User',
                  profile,
                  bookings,
                  plansById,
                  user.id,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String userName,
    UserProfileModel? profile,
    List<BookingModel> bookings,
    Map<String, dynamic> plansById,
    String userId,
  ) {
    final activeSubscription = _latestActiveSubscription(
      bookings,
      plansById: plansById,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref, profile, userName),
                const SizedBox(height: 24),
                _buildActivePlanCard(context, activeSubscription),
                const SizedBox(height: 28),
                _buildSectionTitle(
                  'Your Vehicles',
                  actionText: 'Manage',
                  onAction: () {
                    Navigator.pushNamed(context, '/edit-profile');
                  },
                ),
                const SizedBox(height: 12),
                _buildGarageWithSubscription(
                  context,
                  profile,
                  bookings,
                  userId,
                ),
                const SizedBox(height: 28),
                _buildQuickActions(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    UserProfileModel? profile,
    String fallbackName,
  ) {
    final name = profile?.fullName ?? fallbackName;
    final tier = (profile?.membershipTier ?? 'Guest').toUpperCase();
    final avatarUrl = profile?.avatarUrl;

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$tier MEMBER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[600],
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  Widget _buildActivePlanCard(
    BuildContext context,
    _PlanRef? activeSubscription,
  ) {
    final hasPlan = activeSubscription != null && !activeSubscription.isExpired;
    final planName = activeSubscription?.name ?? 'Choose a subscription plan';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasPlan
            ? const LinearGradient(
                colors: [Color(0xFFFF7A18), Color(0xFFFF4D00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasPlan ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasPlan ? Colors.transparent : Colors.grey[200]!,
        ),
        boxShadow: hasPlan
            ? [
                BoxShadow(
                  color: const Color(0xFFFF7A18).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasPlan ? 'ACTIVE PLAN' : 'NO ACTIVE PLAN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: hasPlan
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              if (hasPlan && activeSubscription.showUnlimited) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.all_inclusive, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'UNLIMITED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            planName,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: hasPlan ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (hasPlan) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.all_inclusive, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Unlimited Washes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasPlan && activeSubscription.expiresAt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activeSubscription.isExpired
                        ? Icons.warning
                        : Icons.calendar_today,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeSubscription.isExpired
                        ? 'Expired'
                        : 'Valid till ${DateFormat('dd MMM yyyy').format(activeSubscription.expiresAt!)} (${activeSubscription.daysRemaining} days left)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              if (hasPlan) {
                Navigator.pushNamed(context, '/booking');
              } else {
                Navigator.pushNamed(context, '/our-services/subscription');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPlan ? Colors.white : const Color(0xFFFF7A18),
              foregroundColor: hasPlan ? const Color(0xFFFF7A18) : Colors.white,
            ),
            child: Text(hasPlan ? 'Manage Bookings' : 'View Plans'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }

  Widget _buildGarage(
    UserProfileModel? profile,
    List<BookingModel> bookings,
    BuildContext context,
    Map<String, bool> subscriptionStatus,
  ) {
    final vehicles = profile?.vehicles ?? const [];
    if (vehicles.isEmpty) {
      return _buildEmptyCard(
        'No vehicles added.',
        'Add your car from profile to enable booking.',
        action: () => Navigator.pushNamed(context, '/edit-profile'),
        actionText: 'Add Vehicle',
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40 - 24) / 2;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final hasSubscription =
            subscriptionStatus[vehicle.licensePlate.toUpperCase()] ?? false;
        final last = bookings
            .where((b) => b.vehicleNumber == vehicle.licensePlate)
            .toList();
        final lastDate = last.isEmpty ? null : last.first.appointmentDate;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.model,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasSubscription)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SUBSCRIBED',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.licensePlate,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastDate == null
                          ? 'No previous washes'
                          : 'Last wash: ${DateFormat('dd MMM yyyy').format(lastDate)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: hasSubscription
                    ? OutlinedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/booking'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12),
                        ),
                        child: const Text('View Subscription'),
                      )
                    : ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/subscription-choice',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE85A10),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12),
                        ),
                        child: const Text('SUBSCRIBE'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGarageWithSubscription(
    BuildContext context,
    UserProfileModel? profile,
    List<BookingModel> bookings,
    String userId,
  ) {
    return FutureBuilder<Map<String, bool>>(
      future: _loadSubscriptionStatus(userId, profile?.vehicles ?? []),
      builder: (context, snapshot) {
        final subscriptionStatus = snapshot.data ?? {};
        return _buildGarage(profile, bookings, context, subscriptionStatus);
      },
    );
  }

  Future<Map<String, bool>> _loadSubscriptionStatus(
    String userId,
    List<dynamic> vehicles,
  ) async {
    if (vehicles.isEmpty) return {};

    try {
      final vehicleNumbers = vehicles
          .map((v) => v.licensePlate as String)
          .toList();
      return await BookingValidationHelper.getAllVehiclesSubscriptionStatus(
        userId: userId,
        vehicleNumbers: vehicleNumbers,
      );
    } catch (e) {
      return {};
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _actionTile(
          'History',
          Icons.history,
          () => Navigator.pushNamed(context, '/history'),
        ),
        _actionTile(
          'FAQ',
          Icons.help_outline,
          () => Navigator.pushNamed(context, '/faq'),
        ),
        _actionTile(
          'Support',
          Icons.support_agent,
          () => Navigator.pushNamed(context, '/chat'),
        ),
        _actionTile(
          'Settings',
          Icons.settings,
          () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _actionTile(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF13B6EC)),
            const Spacer(),
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(List<BookingModel> bookings) {
    final history = bookings
        .where(
          (b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled,
        )
        .take(3)
        .toList();
    if (history.isEmpty) {
      return _buildEmptyCard(
        'No history yet.',
        'Completed services appear here.',
      );
    }

    return Column(
      children: history.map((b) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_car_wash_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceNameFromRef(b.serviceId),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(b.appointmentDate)} • ${b.vehicleName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${b.totalPrice.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(
    String title,
    String subtitle, {
    VoidCallback? action,
    String? actionText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          if (action != null && actionText != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: action, child: Text(actionText)),
          ],
        ],
      ),
    );
  }

  _PlanRef? _latestActiveSubscription(
    List<BookingModel> bookings, {
    Map<String, dynamic>? plansById,
  }) {
    final subs = bookings
        .where(
          (b) =>
              b.status != BookingStatus.cancelled &&
              b.serviceId.startsWith('subscription::'),
        )
        .toList();
    if (subs.isEmpty) return null;
    subs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestSub = subs.first;
    final parts = latestSub.serviceId.split('::');

    String name = 'Subscription';
    bool showUnlimited = false;
    int? totalAllowed;
    String? duration;

    if (parts.length >= 3) {
      name = parts.sublist(2).join('::');
    }

    // Get plan details if available
    if (parts.length >= 2 && plansById != null) {
      final planId = parts[1];
      final plan = plansById[planId];
      if (plan != null) {
        duration = plan['duration'] as String?;
        showUnlimited = plan['show_unlimited'] == true;
      }
    }

    return _PlanRef(
      id: parts.length >= 2 ? parts[1] : 'unknown',
      name: name,
      startedAt: latestSub.createdAt,
      duration: duration,
      totalAllowed: totalAllowed,
      showUnlimited: showUnlimited,
    );
  }

  String _serviceNameFromRef(String ref) {
    final parts = ref.split('::');
    if (parts.length >= 3) return parts.sublist(2).join('::');
    return ref;
  }
}

class _PlanRef {
  final String id;
  final String name;
  final DateTime? startedAt;
  final String? duration;
  final int? totalAllowed;
  final bool showUnlimited;

  _PlanRef({
    required this.id,
    required this.name,
    this.startedAt,
    this.duration,
    this.totalAllowed,
    this.showUnlimited = false,
  });

  DateTime? get expiresAt {
    if (startedAt == null || duration == null) return null;
    if (duration == 'Monthly') {
      return DateTime(startedAt!.year, startedAt!.month + 1, startedAt!.day);
    } else if (duration == 'Yearly') {
      return DateTime(startedAt!.year + 1, startedAt!.month, startedAt!.day);
    }
    return null;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  int get daysRemaining {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inDays;
  }
}

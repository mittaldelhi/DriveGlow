import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/providers/profile_providers.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/notification_providers.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/models/notification_model.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<BookingModel> _recentBookings = [];
  bool _loadingBookings = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBookings();
  }

  Future<void> _loadRecentBookings() async {
    try {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        final bookings = await ref.read(bookingRepositoryProvider).getUserBookings(profile.id);
        setState(() {
          _recentBookings = bookings.where((b) => 
            b.status == BookingStatus.completed || 
            b.status == BookingStatus.cancelled
          ).take(3).toList();
          _loadingBookings = false;
        });
      }
    } catch (e) {
      setState(() => _loadingBookings = false);
    }
  }

  String _getServiceName(BookingModel booking) {
    final serviceId = booking.serviceId;
    if (serviceId.startsWith('subscription::')) {
      final parts = serviceId.split('::');
      if (parts.length >= 3) return parts[2];
      return 'Subscription Plan';
    }
    if (serviceId.startsWith('subscription_service::')) {
      final parts = serviceId.split('::');
      if (parts.length >= 4) return parts[3];
      return 'Subscription Service';
    }
    // For regular services, check if it's a UUID (length 36) or has service name
    if (serviceId.length == 36 || serviceId.contains('-')) {
      return 'Standard Service';
    }
    return serviceId;
  }

  String _getServiceTag(BookingModel booking) {
    final serviceId = booking.serviceId;
    if (serviceId.startsWith('subscription::') || serviceId.startsWith('subscription_service::')) {
      return 'Subscription';
    }
    return 'Paid';
  }

  IconData _getServiceIcon(BookingModel booking) {
    final serviceId = booking.serviceId.toLowerCase();
    if (serviceId.contains('subscription')) {
      return Icons.card_membership;
    }
    if (serviceId.contains('ceramic') || serviceId.contains('coating')) {
      return Icons.auto_awesome;
    }
    if (serviceId.contains('interior')) {
      return Icons.cleaning_services;
    }
    if (serviceId.contains('exterior') || serviceId.contains('wash')) {
      return Icons.local_car_wash;
    }
    if (serviceId.contains('tire') || serviceId.contains('shine')) {
      return Icons.tire_repair;
    }
    if (serviceId.contains('polish') || serviceId.contains('wax')) {
      return Icons.auto_fix_high;
    }
    return Icons.car_repair;
  }

  Widget _buildCustomerRatingBadge(UserProfileModel? profile) {
    if (profile == null) return const SizedBox.shrink();
    
    final currentUserTier = Supabase.instance.client.auth.currentUser?.userMetadata?['membership_tier']?.toString()?.toUpperCase();
    final isStaffOrAdmin = currentUserTier == 'STAFF' || currentUserTier == 'ADMIN';
    
    if (!isStaffOrAdmin) return const SizedBox.shrink();
    
    final customerRating = profile.customerRating ?? 0.0;
    final totalFeedbacks = profile.totalCustomerFeedbacks ?? 0;
    
    if (totalFeedbacks == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getRatingColor(customerRating).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getRatingColor(customerRating).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.thumb_up_rounded,
            size: 14,
            color: _getRatingColor(customerRating),
          ),
          const SizedBox(width: 4),
          Text(
            '${customerRating.toStringAsFixed(1)} ($totalFeedbacks reviews)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getRatingColor(customerRating),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
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
          data: (profile) => _buildContent(context, profile),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFE85A10)),
          ),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserProfileModel? profile) {
    return CustomScrollView(
      slivers: [
        // --- Profile Content ---
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNotificationHeader(context),
              _buildProfileHeader(context, profile),
              _buildNotificationSettingsSection(),
              _buildPromoCodesSection(),
              _buildTransactionsSection(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationHeader(BuildContext context) {
    final notificationsAsync = ref.watch(currentUserNotificationsProvider);
    final user = Supabase.instance.client.auth.currentUser;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'My Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showNotificationsPanel(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE85A10).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFFE85A10),
                    size: 24,
                  ),
                  notificationsAsync.when(
                    data: (notifications) {
                      final unreadCount = notifications.where((n) => !n.isRead).length;
                      if (unreadCount == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildNotificationsList(controller),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(ScrollController controller) {
    final notificationsAsync = ref.watch(currentUserNotificationsProvider);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    final repo = ref.read(notificationRepositoryProvider);
                    await repo.markAllAsRead(user.id);
                    ref.invalidate(currentUserNotificationsProvider);
                  }
                },
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationItem(notification);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    IconData icon;
    Color color;
    
    switch (notification.type) {
      case 'booking_complete':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'payment':
        icon = Icons.payment;
        color = Colors.blue;
        break;
      case 'subscription':
        icon = Icons.card_membership;
        color = Colors.orange;
        break;
      case 'promotion':
        icon = Icons.card_giftcard;
        color = Colors.purple;
        break;
      case 'feedback':
        icon = Icons.star;
        color = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.orange[100]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: GoogleFonts.inter(
                    fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNotificationTime(notification.createdAt),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dateTime);
  }

  Widget _buildProfileHeader(BuildContext context, UserProfileModel? profile) {
    // DEBUG: Check if username is received from database
    debugPrint('DEBUG - Profile username: ${profile?.username}');
    debugPrint('DEBUG - Full profile: $profile');
    
    final name = profile?.fullName ?? 'Julian Vance';
    final tier = profile?.membershipTier ?? 'GOLD MEMBER';
    final avatar =
        profile?.avatarUrl ??
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop";

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Avatar with Edit Button
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE85A10).withValues(alpha: 0.2),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(avatar),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE85A10),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User Info
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          if (profile?.username != null && profile!.username!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '@${profile!.username}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Color(0xFFE85A10), size: 16),
              const SizedBox(width: 4),
              Text(
                tier.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE85A10),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCustomerRatingBadge(profile),
          const SizedBox(height: 4),
          Text(
            profile != null
                ? 'Member since ${_getMonthName(profile.createdAt.month)} ${profile.createdAt.year}'
                : 'Member since March 2023',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF1C120D).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE85A10).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/edit-profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85A10),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE85A10).withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.share_outlined,
                  color: Color(0xFFE85A10),
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Settings',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE85A10).withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: () => Navigator.pushNamed(context, '/admin'),
              leading: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85A10).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFFE85A10),
                ),
              ),
              title: Text(
                'Go to Admin Panel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Manage services and bookings',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFFE85A10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildNotificationSettingsSection() {
    final prefsAsync = ref.watch(currentUserNotificationPrefsProvider);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Settings',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: prefsAsync.when(
              data: (prefs) => Column(
                children: [
                  _buildNotificationToggle(
                    'Push Notifications',
                    'Receive notifications on your device',
                    prefs.pushEnabled,
                    (value) => _updateNotificationPref('push', value),
                  ),
                  const Divider(),
                  _buildNotificationToggle(
                    'Booking Updates',
                    'Get notified when service is completed',
                    prefs.notifyBookingComplete,
                    (value) => _updateNotificationPref('booking', value),
                  ),
                  const Divider(),
                  _buildNotificationToggle(
                    'Payment Alerts',
                    'Get notified for payments and transactions',
                    prefs.notifyPaymentDone,
                    (value) => _updateNotificationPref('payment', value),
                  ),
                  const Divider(),
                  _buildNotificationToggle(
                    'Subscription Updates',
                    'Get notified for subscription activations',
                    prefs.notifySubscriptionDone,
                    (value) => _updateNotificationPref('subscription', value),
                  ),
                  const Divider(),
                  _buildNotificationToggle(
                    'Promotions & Offers',
                    'Receive promotional messages',
                    prefs.notifyPromotions,
                    (value) => _updateNotificationPref('promotions', value),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading settings: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE85A10),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNotificationPref(String type, bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final repo = ref.read(notificationRepositoryProvider);
    
    switch (type) {
      case 'push':
        await repo.updatePreferences(user.id, pushEnabled: value);
        break;
      case 'booking':
        await repo.updatePreferences(user.id, notifyBookingComplete: value);
        break;
      case 'payment':
        await repo.updatePreferences(user.id, notifyPaymentDone: value);
        break;
      case 'subscription':
        await repo.updatePreferences(user.id, notifySubscriptionDone: value);
        break;
      case 'promotions':
        await repo.updatePreferences(user.id, notifyPromotions: value);
        break;
    }
    
    ref.invalidate(currentUserNotificationPrefsProvider);
  }

  // Provider reference for notification preferences
  final currentUserNotificationPrefsProvider = FutureProvider<NotificationPreferencesModel>((ref) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return NotificationPreferencesModel();
    
    final repo = ref.watch(notificationRepositoryProvider);
    return repo.getPreferences(user.id);
  });

  Widget _buildPromoCodesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Promos',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE85A10).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE85A10).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_offer, color: Color(0xFFE85A10)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DRIVE20',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C120D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '20% off on first subscription',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE85A10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Apply',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_giftcard, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REFER50',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C120D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹500 credits on referring a friend',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Share',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transactions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: () => Navigator.pushNamed(context, '/transactions'),
              leading: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: PremiumTheme.orangePrimary,
                ),
              ),
              title: Text(
                'View All Transactions',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Subscription purchases & bookings',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: PremiumTheme.orangePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHistorySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service History',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C120D),
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingBookings)
            const Center(child: CircularProgressIndicator(color: Color(0xFFE85A10)))
          else if (_recentBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No service history yet',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your completed services will appear here',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            ..._recentBookings.map((booking) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildHistoryItem(
                title: _getServiceName(booking),
                tag: _getServiceTag(booking),
                price: '₹${booking.totalPrice.toStringAsFixed(0)}',
                date: DateFormat('MMM dd, yyyy').format(booking.appointmentDate),
                vehicle: booking.vehicleName,
                icon: _getServiceIcon(booking),
                status: booking.status,
              ),
            )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFFE85A10,
                ).withValues(alpha: 0.05),
                foregroundColor: const Color(0xFFE85A10),
                elevation: 0,
                side: BorderSide(
                  color: const Color(0xFFE85A10).withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View Full History',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required String title,
    required String tag,
    required String price,
    required String date,
    required String vehicle,
    required IconData icon,
    BookingStatus? status,
  }) {
    final isCancelled = status == BookingStatus.cancelled;
    final isSubscription = tag == 'Subscription';
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled 
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: isCancelled 
                  ? Colors.red.withValues(alpha: 0.1)
                  : const Color(0xFFE85A10).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isCancelled ? Colors.red : const Color(0xFFE85A10)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isSubscription ? 'SUBSCRIPTION' : 'REGULAR',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$date • $vehicle',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      price,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
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

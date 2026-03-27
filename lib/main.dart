import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shinex/theme/app_theme.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/signup_screen.dart';
import 'presentation/profile/edit_profile_screen.dart';
import 'presentation/profile/transactions_screen.dart';
import 'presentation/booking/payment_screen.dart';
import 'presentation/booking/subscription_services_booking_screen.dart';
import 'presentation/booking/booking_success_screen.dart';
import 'presentation/booking/check_in_ticket_screen.dart';
import 'presentation/booking/service_done_screen.dart';
import 'presentation/admin/widgets/admin_scaffold.dart';
import 'presentation/admin/screens/customer_detail_screen.dart';
import 'presentation/support/screens/chat_screen.dart';
import 'presentation/booking/screens/feedback_screen.dart';
import 'presentation/booking/screens/history_screen.dart';
import 'presentation/profile/settings_screen.dart';
import 'presentation/widgets/under_construction_screen.dart';
import 'presentation/staff/staff_login_screen.dart';
import 'presentation/services/faq_screen.dart';
import 'presentation/staff/staff_panel_screen.dart';
import 'presentation/staff/staff_forgot_password_screen.dart';
import 'presentation/staff/staff_edit_profile_screen.dart';
import 'presentation/staff/staff_qr_scanner_screen.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'presentation/widgets/main_scaffold.dart';
import 'presentation/services/standard_care_screen.dart';
import 'presentation/services/subscription_screen.dart';
import 'presentation/services/maintenance_screen.dart';
import 'presentation/services/accessories_screen.dart';
import 'presentation/services/promos_screen.dart';

import 'presentation/admin/screens/admin_standard_services_screen.dart';
import 'presentation/admin/screens/admin_coupon_management_screen.dart';
import 'presentation/admin/screens/admin_staff_management_screen.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fqgifkijuykxkusxoeqe.supabase.co',
    anonKey: 'sb_publishable_z0O1Te1Hv7w7PwqHISiOMQ_hKoBBSt2',
  );

  runApp(const ProviderScope(child: AquaGlossApp()));
}

class AquaGlossApp extends StatelessWidget {
  const AquaGlossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveGlow',
      debugShowCheckedModeBanner: false,
      theme: PremiumTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScaffold(initialIndex: 0),
        '/services': (context) => const MainScaffold(initialIndex: 1),
        '/booking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MainScaffold(
            initialIndex: 2,
            bookingInitialTab: args?['openTab'] as String?,
          );
        },
        '/profile': (context) => const MainScaffold(initialIndex: 3),
        '/login': (context) => const MainScaffold(
          initialIndex: 3,
          showAppBar: false,
          child: LoginScreen(),
        ),
        '/staff-login': (context) => const StaffLoginScreen(),
        '/staff': (context) => _StaffRouteGuard(child: const StaffPanelScreen()),
        '/staff-forgot-password': (context) => const StaffForgotPasswordScreen(),
        '/staff-edit-profile': (context) => const StaffEditProfileScreen(),
        '/staff-qr-scanner': (context) => const StaffQrScannerScreen(),
        '/signup': (context) => const MainScaffold(
          initialIndex: 3,
          showAppBar: false,
          child: SignupScreen(),
        ),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/transactions': (context) => const TransactionsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/faq': (context) => const FaqScreen(),
        '/promos': (context) => const PromosScreen(),
        '/dashboard': (context) => const MainScaffold(initialIndex: 3),
        '/select-service': (context) =>
            const MainScaffold(initialIndex: 1, child: StandardCareScreen()),
        '/subscription-choice': (context) => const MainScaffold(
          initialIndex: 1,
          child: SubscriptionScreen(),
        ),
        '/payment': (context) => const PaymentScreen(),
        '/subscription-services': (context) =>
            const SubscriptionServicesBookingScreen(),
        '/booking-success': (context) {
          final raw = ModalRoute.of(context)?.settings.arguments;
          if (raw is Map<String, dynamic>) {
            final appointmentRaw = raw['appointmentDate'] as String?;
            return BookingSuccessScreen(
              bookingId: raw['bookingId'] as String?,
              bookingIds: (raw['bookingIds'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [],
              isService: raw['isService'] as bool? ?? true,
              itemName: raw['itemName'] as String? ?? 'Booking',
              total: (raw['total'] as num?)?.toDouble() ?? 0,
              vehicleCount: raw['vehicleCount'] as int? ?? 1,
              appointmentDate: appointmentRaw != null
                  ? DateTime.tryParse(appointmentRaw)
                  : null,
              validityLabel: raw['validityLabel'] as String? ?? '',
            );
          }
          final args = raw as String?;
          return BookingSuccessScreen(bookingId: args);
        },
        '/check-in': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return CheckInTicketScreen(bookingId: args);
        },
        '/service-done': (context) => const ServiceDoneScreen(),
        '/admin': (context) => _AdminRouteGuard(child: const AdminScaffold(initialIndex: 0)),
        '/admin/dashboard': (context) => _AdminRouteGuard(child: const AdminScaffold(initialIndex: 1)),
        '/admin/home': (context) => _AdminRouteGuard(child: const AdminScaffold(initialIndex: 0)),
        '/admin/settings': (context) => _AdminRouteGuard(child: const AdminScaffold(initialIndex: 2)),
        '/admin/profile': (context) => _AdminRouteGuard(child: const AdminScaffold(initialIndex: 3)),
        '/chat': (context) => const SupportChatScreen(),
        '/customer-detail': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return CustomerDetailScreen(userId: args?['userId'] ?? 'DEFAULT');
        },
        '/feedback': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return FeedbackScreen(bookingId: args?['bookingId'] ?? 'DEFAULT');
        },
        '/history': (context) => const HistoryScreen(),
        '/under-construction': (context) => const UnderConstructionScreen(),
        '/our-services/standard-care': (context) =>
            const MainScaffold(initialIndex: 1, child: StandardCareScreen()),
        '/our-services/subscription': (context) =>
            const MainScaffold(initialIndex: 1, child: SubscriptionScreen()),
        '/our-services/maintenance': (context) => const MainScaffold(
          initialIndex: 1,
          showAppBar: false,
          child: MaintenanceScreen(),
        ),
        '/our-services/accessories': (context) => const MainScaffold(
          initialIndex: 1,
          showAppBar: false,
          child: AccessoriesScreen(),
        ),
        '/admin-standard-services': (context) =>
            const AdminStandardServicesScreen(),
        '/admin/coupons': (context) => const AdminCouponManagementScreen(),
        '/admin/hr-home': (context) => const AdminStaffManagementScreen(),
      },
    );
  }
}

class _AdminRouteGuard extends StatelessWidget {
  final Widget child;
  
  const _AdminRouteGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAdminAccess(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.data != true) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Access Denied'),
                  const SizedBox(height: 8),
                  const Text('This area is for admins only.'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/staff-login'),
                    child: const Text('Go to Staff Login'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return child;
      },
    );
  }

  Future<bool> _checkAdminAccess() async {
    try {
      final client = Supabase.instance.client;
      
      // Use OLD Supabase Auth system only
      var user = client.auth.currentUser;
      
      // If no user, return false
      if (user == null) return false;
      
      // Try to refresh session to get latest metadata
      try {
        await client.auth.refreshSession();
        user = client.auth.currentUser;
      } catch (_) {
        // Refresh failed, continue with current user
      }
      
      // Check user metadata first (fastest check)
      final metadata = user?.userMetadata ?? {};
      final appMetadata = user?.appMetadata ?? {};
      final membershipTier = (metadata['membership_tier'] ?? appMetadata['membership_tier'] ?? '').toString().toUpperCase();
      
      if (membershipTier == 'ADMIN') {
        return true;
      }
      
      // Check specific admin email
      final email = (user?.email ?? '').toLowerCase();
      if (email == 'admin@gmail.com') {
        return true;
      }
      
      // Use is_admin_user function (bypasses RLS via security definer)
      final isAdmin = await client.rpc('is_admin_user');
      
      return isAdmin == true;
    } catch (e) {
      return false;
    }
  }
}

class _StaffRouteGuard extends StatelessWidget {
  final Widget child;
  
  const _StaffRouteGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkStaffAccess(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.data != true) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Access Denied'),
                  const SizedBox(height: 8),
                  const Text('This area is for staff only.'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/staff-login'),
                    child: const Text('Go to Staff Login'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return child;
      },
    );
  }

  Future<bool> _checkStaffAccess() async {
    try {
      final client = Supabase.instance.client;
      
      // Use OLD Supabase Auth system only
      var user = client.auth.currentUser;
      
      // If no user, return false
      if (user == null) return false;
      
      // Try to refresh session to get latest metadata
      try {
        await client.auth.refreshSession();
        user = client.auth.currentUser;
      } catch (_) {
        // Refresh failed, continue with current user
      }
      
      // Check user metadata first (fastest check)
      final metadata = user?.userMetadata ?? {};
      final appMetadata = user?.appMetadata ?? {};
      final membershipTier = (metadata['membership_tier'] ?? appMetadata['membership_tier'] ?? '').toString().toUpperCase();
      
      if (membershipTier == 'STAFF' || membershipTier == 'ADMIN') {
        return true;
      }
      
      // Use is_staff_user function (bypasses RLS via security definer)
      final isStaff = await client.rpc('is_staff_user');
      
      return isStaff == true;
    } catch (e) {
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_page_section.dart';
import '../services/services_screen.dart';
import '../booking/user_bookings_screen.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../staff/staff_panel_screen.dart';
import '../../application/providers/auth_providers.dart';
import '../../theme/app_theme.dart';

class NavNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final navIndexProvider = NotifierProvider<NavNotifier, int>(() => NavNotifier());

class MainScaffold extends ConsumerStatefulWidget {
  final int initialIndex;
  final Widget? child;
  final bool showAppBar;
  final String? bookingInitialTab;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.child,
    this.showAppBar = true,
    this.bookingInitialTab,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  late final Future<bool> _staffModeFuture;

  @override
  void initState() {
    super.initState();
    _staffModeFuture = _isStaffSession();
    // Reset navigation index on init (hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navIndexProvider.notifier).setIndex(widget.initialIndex);
    });
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update navigation index when widget updates
    if (oldWidget.initialIndex != widget.initialIndex) {
      ref.read(navIndexProvider.notifier).setIndex(widget.initialIndex);
    }
  }

  Future<bool> _isStaffSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      // Use is_staff_user function to bypass RLS
      final isStaff = await Supabase.instance.client
          .rpc('is_staff_user');
      return isStaff == true;
    } catch (e) {
      // Fallback
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _staffModeFuture,
      builder: (context, staffSnapshot) {
        if (staffSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (staffSnapshot.data == true) {
          return const StaffPanelScreen();
        }

        final selectedIndex = ref.watch(navIndexProvider);

        final List<Widget> screens = [
          const HomePageSection(),
          const OurServicesScreen(),
          UserBookingsScreen(initialTab: widget.bookingInitialTab),
          ref.watch(isGuestProvider) ? const LoginScreen() : const DashboardScreen(),
        ];

        return Scaffold(
          appBar:
              (widget.showAppBar && (selectedIndex != 0 || widget.child != null))
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      centerTitle: true,
                      toolbarHeight: 70,
                      automaticallyImplyLeading: false,
                      leading: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      title: Text(
                        widget.child != null
                            ? 'DriveGlow Studio'
                            : selectedIndex == 1
                            ? 'Our Services'
                            : selectedIndex == 2
                            ? 'My Bookings'
                            : selectedIndex == 3
                            ? 'My Profile'
                            : 'DriveGlow Studio',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF1A1A1A),
                              size: 24,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body:
              widget.child ?? IndexedStack(index: selectedIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) {
                final isGuest = ref.read(isGuestProvider);
                if ((index == 2 || index == 3) && isGuest) {
                  Navigator.pushNamed(context, '/login');
                  return;
                }

                if (widget.child != null) {
                  const routeByIndex = ['/', '/services', '/booking', '/profile'];
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    routeByIndex[index],
                    (route) => false,
                  );
                } else {
                  ref.read(navIndexProvider.notifier).setIndex(index);
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: PremiumTheme.orangePrimary,
              unselectedItemColor: Colors.grey[400],
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.home_rounded),
                  ),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.waves_rounded),
                  ),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.calendar_today_rounded),
                  ),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

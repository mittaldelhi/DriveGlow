import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/booking_providers.dart';
import '../../domain/models/booking_model.dart';
import '../../domain/models/feedback_model.dart';
import '../../theme/app_theme.dart';
import 'widgets/active_booking_tab.dart';
import 'widgets/subscriptions_tab.dart';
import 'screens/history_screen.dart';

class UserBookingsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const UserBookingsScreen({super.key, this.initialTab});

  @override
  ConsumerState<UserBookingsScreen> createState() => _UserBookingsScreenState();
}

class _UserBookingsScreenState extends ConsumerState<UserBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['My Subscription', 'My Booking', 'History'];

  bool _isLoading = true;
  String? _error;
  List<BookingModel> _bookings = const [];
  Map<String, Map<String, dynamic>> _plansById = {};
  Map<String, FeedbackModel> _feedbackByBookingId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use initialTab from widget or from route arguments
      String? tabToUse = widget.initialTab;
      bool shouldRefresh = false;

      if (tabToUse == null) {
        final args = ModalRoute.of(context)?.settings.arguments as Map?;
        tabToUse = args?['openTab'] as String?;
        shouldRefresh = args?['refresh'] == true;
      } else {
        shouldRefresh = true; // If initialTab is set, refresh data
      }

      if (tabToUse != null) {
        int tabIndex = 0;
        if (tabToUse == 'subscriptions')
          tabIndex = 0;
        else if (tabToUse == 'active')
          tabIndex = 1;
        else if (tabToUse == 'history')
          tabIndex = 2;

        if (tabIndex >= 0 && tabIndex < _tabs.length) {
          _tabController.animateTo(tabIndex);
        }
      }

      // Refresh data if requested
      if (shouldRefresh) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to view bookings.');
      }

      final bookingRepo = ref.read(bookingRepositoryProvider);
      final bookings = await bookingRepo.getUserBookings(user.id);

      Map<String, Map<String, dynamic>> plans = {};
      try {
        final plansResponse = await Supabase.instance.client
            .from('subscription_plans')
            .select(
              'id, name, duration, tier, included_service_ids, service_usage_limits',
            );
        plans = {
          for (final row in (plansResponse as List))
            row['id'] as String: Map<String, dynamic>.from(row),
        };
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _plansById = plans;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Bookings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: PremiumTheme.orangePrimary,
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        color: PremiumTheme.orangePrimary,
                        width: 3,
                      ),
                    ),
                    tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SubscriptionsTab(
                        bookings: _bookings,
                        plansById: _plansById,
                        onRefresh: _loadData,
                      ),
                      ActiveBookingTab(
                        bookings: _bookings,
                        onRefresh: _loadData,
                      ),
                      HistoryScreen(bookings: _bookings, onRefresh: _loadData),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 42),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Failed to load bookings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
